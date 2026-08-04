import SwiftUI

/// Three-step onboarding: name → friends + DUPR → availability.
///
/// Step 1 creates the profile. Steps 2 and 3 are skippable — the user can always come back
/// to them from Profile and the planner. `appState.loadProfile()` fires only when the user
/// finishes or skips the last step, so ContentView keeps showing OnboardingView until then.
struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var locationManager: LocationManager

    @State private var step = 1

    // Step 1 — identity
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var username = ""

    // Step 2 — friends + DUPR
    @State private var friendsVM = FriendsViewModel()
    @State private var friendSearchText = ""
    @State private var duprConnected = false
    @State private var duprProfile: DUPRService.DUPRProfile?

    // Step 3 — availability
    @State private var dayParts: [Int: Set<DayPart>] = [:]

    // Shared
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.stackBackground.ignoresSafeArea()

            Group {
                switch step {
                case 1: nameStep
                case 2: friendsStep
                default: availabilityStep
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(Motion.transition, value: step)
        }
    }

    // MARK: - Step 1: Name + username

    private var nameStep: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 48)

                stepHeader(
                    title: "What's your name?",
                    subtitle: "This is how other players will find you."
                )

                VStack(spacing: 14) {
                    formField(icon: "person", placeholder: "First name", text: $firstName)
                        .textContentType(.givenName)

                    formField(icon: "person", placeholder: "Last name", text: $lastName)
                        .textContentType(.familyName)

                    formField(icon: "at", placeholder: "Username", text: $username)
                        .textContentType(.username)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                }
                .padding(.horizontal, 24)

                errorLabel

                Button(action: submitName) {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Continue")
                    }
                }
                .primaryButton()
                .padding(.horizontal, 24)
                .disabled(isLoading)

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Step 2: Friends + DUPR

    private var friendsStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 32)

                stepHeader(
                    title: "Add friends",
                    subtitle: "See when they're free and invite them to games."
                )

                // Friend search
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundColor(.stackSecondaryText)
                        TextField("Search players by name", text: $friendSearchText)
                            .font(AppFonts.body())
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(AppConstants.buttonCornerRadius)

                    if !friendsVM.searchResults.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(friendsVM.searchResults) { user in
                                friendRow(user: user)
                                if user.id != friendsVM.searchResults.last?.id {
                                    Divider().padding(.leading, 56)
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    } else if friendSearchText.count >= 2 {
                        Text("No players found.")
                            .font(AppFonts.callout())
                            .foregroundColor(.stackSecondaryText)
                            .padding(.vertical, 4)
                    }

                    if !friendsVM.pendingSentIds.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.stackGreen)
                            Text("\(friendsVM.pendingSentIds.count) request\(friendsVM.pendingSentIds.count == 1 ? "" : "s") sent")
                                .font(AppFonts.callout())
                                .foregroundColor(.stackSecondaryText)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .onChange(of: friendSearchText) {
                    friendsVM.searchText = friendSearchText
                    Task { await friendsVM.search() }
                }

                // DUPR
                DUPRConnectView(
                    onConnected: { profile in
                        duprProfile = profile
                        duprConnected = true
                    },
                    allowSkip: false,
                    isConnected: duprConnected
                )
                .padding(.horizontal, 24)

                // Continue / Skip
                VStack(spacing: 12) {
                    Button { withAnimation { step = 3 } } label: {
                        Text("Continue")
                    }
                    .primaryButton()

                    Button { withAnimation { step = 3 } } label: {
                        Text("Skip for now")
                            .font(AppFonts.body())
                            .fontWeight(.medium)
                            .foregroundColor(.stackSecondaryText)
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 40)
            }
        }
        .task { await friendsVM.load() }
    }

    private func friendRow(user: User) -> some View {
        HStack(spacing: 12) {
            AvatarCircle(urlString: user.avatarUrl, name: user.displayName, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(AppFonts.body())
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text("@\(user.username)")
                    .font(AppFonts.caption())
                    .foregroundColor(.stackSecondaryText)
            }

            Spacer()

            if friendsVM.pendingSentIds.contains(user.id) {
                Text("Sent")
                    .font(AppFonts.subheadline())
                    .fontWeight(.medium)
                    .foregroundColor(.stackSecondaryText)
            } else {
                Button {
                    Task { await friendsVM.sendRequest(to: user.id) }
                } label: {
                    Text("Add")
                        .font(AppFonts.callout())
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.stackGreen)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Step 3: Availability

    private var availabilityStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 32)

                stepHeader(
                    title: "When do you usually play?",
                    subtitle: "Friends can see your times and plan around them."
                )

                DayPartGrid(selection: $dayParts)
                    .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    Button(action: finishOnboarding) {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Done")
                        }
                    }
                    .primaryButton()
                    .disabled(isLoading)

                    Button(action: finishOnboarding) {
                        Text("Skip for now")
                            .font(AppFonts.body())
                            .fontWeight(.medium)
                            .foregroundColor(.stackSecondaryText)
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Shared pieces

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(AppFonts.pageTitle())
                .foregroundColor(.primary)

            Text(subtitle)
                .font(AppFonts.body())
                .foregroundColor(.stackSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private var errorLabel: some View {
        if let error = errorMessage {
            Text(error)
                .font(AppFonts.callout())
                .foregroundColor(.red)
                .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private func formField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(AppFonts.body())
                .foregroundColor(.stackInputIcon)
            TextField(placeholder, text: text)
                .font(AppFonts.body())
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(AppConstants.buttonCornerRadius)
    }

    // MARK: - Actions

    private func sanitized(_ input: String) -> String {
        input.unicodeScalars.filter { !$0.properties.isDefaultIgnorableCodePoint && CharacterSet.controlCharacters.inverted.contains($0) }
            .reduce(into: "") { $0.unicodeScalars.append($1) }
    }

    /// Step 1 → creates the profile and advances to step 2.
    private func submitName() {
        errorMessage = nil

        let cleanFirst = sanitized(firstName).trimmingCharacters(in: .whitespaces)
        let cleanLast  = sanitized(lastName).trimmingCharacters(in: .whitespaces)
        let cleanUsername = sanitized(username).trimmingCharacters(in: .whitespaces)

        guard !cleanFirst.isEmpty else { errorMessage = "First name is required"; return }
        guard cleanFirst.count <= 100 else { errorMessage = "First name is too long"; return }
        guard !cleanLast.isEmpty else { errorMessage = "Last name is required"; return }
        guard cleanLast.count <= 100 else { errorMessage = "Last name is too long"; return }
        guard cleanUsername.count >= 3 else { errorMessage = "Username must be at least 3 characters"; return }
        guard cleanUsername.count <= 100 else { errorMessage = "Username is too long"; return }

        isLoading = true
        Task {
            do {
                try await ProfileService.createProfile(
                    firstName: cleanFirst,
                    lastName: cleanLast,
                    middleName: nil,
                    username: cleanUsername,
                    duprRating: 2.5,
                    latitude: locationManager.latitude,
                    longitude: locationManager.longitude
                )
                withAnimation { step = 2 }
            } catch {
                let message = "\(error)"
                if message.lowercased().contains("username") || message.contains("duplicate") || message.contains("unique") || message.contains("23505") || message.contains("users_username_key") {
                    errorMessage = "That username is taken. Try another one."
                } else {
                    let taken = (try? await ProfileService.isUsernameTaken(cleanUsername)) ?? false
                    errorMessage = taken
                        ? "That username is taken. Try another one."
                        : "Something went wrong. Please try again."
                }
            }
            isLoading = false
        }
    }

    /// Final step → saves availability (if any), then loads the profile into AppState so
    /// ContentView swaps to TabBarView.
    private func finishOnboarding() {
        isLoading = true
        Task {
            if dayParts.hasAnySelection {
                try? await ScheduleService.saveSchedule(windows: dayParts.scheduleWindows)
            }
            if let userId = await AuthService.currentUserId() {
                await appState.loadProfile(userId: userId)
            }
            isLoading = false
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
        .environmentObject(LocationManager.shared)
}
