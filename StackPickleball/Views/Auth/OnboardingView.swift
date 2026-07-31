import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var locationManager: LocationManager

    @State private var firstName = ""
    @State private var middleName = ""
    @State private var lastName = ""
    @State private var username = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var duprConnected = false
    @State private var duprProfile: DUPRService.DUPRProfile?
    /// Asked once here so friends' calendars have something on them from day one, instead of
    /// everyone having to remember to broadcast.
    @State private var dayParts: [Int: Set<DayPart>] = [:]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.white, .stackLoginGradientEnd],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 40)

                    VStack(spacing: 8) {
                        Text("Complete Your Profile")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.stackGreen)

                        Text("Tell us about yourself to get started")
                            .font(.system(size: 16))
                            .foregroundColor(.stackSecondaryText)
                    }

                    VStack(spacing: 16) {
                        // First name
                        formField(icon: "person", placeholder: "First Name", text: $firstName)
                            .textContentType(.givenName)

                        // Middle name (optional)
                        formField(icon: "person", placeholder: "Middle Name (optional)", text: $middleName)
                            .textContentType(.middleName)

                        // Last name
                        formField(icon: "person", placeholder: "Last Name", text: $lastName)
                            .textContentType(.familyName)

                        // Username
                        formField(icon: "at", placeholder: "Username", text: $username)
                            .textContentType(.username)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif

                        // DUPR Connect
                        DUPRConnectView(
                            onConnected: { profile in
                                duprProfile = profile
                                duprConnected = true
                            },
                            onSkip: {
                                duprConnected = false
                                duprProfile = nil
                            },
                            allowSkip: true,
                            isConnected: duprConnected
                        )

                        availabilitySection
                    }
                    .padding(.horizontal, 24)

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding(.horizontal, 24)
                    }

                    Button(action: submit) {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Get Started")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.stackGreen)
                    .cornerRadius(14)
                    .padding(.horizontal, 24)
                    .disabled(isLoading)

                    Spacer(minLength: 40)
                }
            }
        }
    }

    private var availabilitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("When do you usually play?")
                .font(.headline)

            Text("Tap the times that usually work \u{2014} you can change these any time.")
                .font(.subheadline)
                .foregroundColor(.stackSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

            DayPartGrid(selection: $dayParts)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "#E5E7EB"), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func formField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#9CA3AF"))
            TextField(placeholder, text: text)
                .font(.system(size: 16))
        }
        .padding()
        .background(Color.white)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "#E5E7EB"), lineWidth: 1)
        )
    }

    private func submit() {
        errorMessage = nil

        guard !firstName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "First name is required"
            return
        }
        guard !lastName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Last name is required"
            return
        }
        guard username.count >= 3 else {
            errorMessage = "Username must be at least 3 characters"
            return
        }

        isLoading = true
        Task {
            do {
                let rating = duprProfile?.dupr_rating ?? 2.5
                try await ProfileService.createProfile(
                    firstName: firstName.trimmingCharacters(in: .whitespaces),
                    lastName: lastName.trimmingCharacters(in: .whitespaces),
                    middleName: middleName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : middleName.trimmingCharacters(in: .whitespaces),
                    username: username,
                    duprRating: rating,
                    latitude: locationManager.latitude,
                    longitude: locationManager.longitude
                )
                // Availability is optional — a failure here shouldn't strand someone who
                // has already created their profile.
                if dayParts.hasAnySelection {
                    try? await ScheduleService.saveSchedule(windows: dayParts.scheduleWindows)
                }

                // Reload profile in app state
                if let userId = await AuthService.currentUserId() {
                    await appState.loadProfile(userId: userId)
                }
            } catch {
                let message = "\(error)"
                if message.lowercased().contains("username") || message.contains("duplicate") || message.contains("unique") || message.contains("23505") || message.contains("users_username_key") {
                    errorMessage = "Username already exists. Please choose a different one."
                } else {
                    // Check if username exists as a fallback for generic edge function errors
                    let taken = (try? await ProfileService.isUsernameTaken(username)) ?? false
                    if taken {
                        errorMessage = "Username already exists. Please choose a different one."
                    } else {
                        errorMessage = "Something went wrong. Please try again."
                    }
                }
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
