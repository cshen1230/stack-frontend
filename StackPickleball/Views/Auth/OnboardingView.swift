import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var locationManager: LocationManager

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var username = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.white, .stackLoginGradientEnd],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 48)

                    // Header
                    VStack(spacing: 8) {
                        Text("What's your name?")
                            .font(AppFonts.pageTitle())
                            .foregroundColor(.primary)

                        Text("This is how other players will find you.")
                            .font(AppFonts.body())
                            .foregroundColor(.stackSecondaryText)
                    }

                    // Fields
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

                    if let error = errorMessage {
                        Text(error)
                            .font(AppFonts.callout())
                            .foregroundColor(.red)
                            .padding(.horizontal, 24)
                    }

                    Button(action: submit) {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Get Started")
                        }
                    }
                    .primaryButton()
                    .padding(.horizontal, 24)
                    .disabled(isLoading)

                    Text("You can connect DUPR and set your\navailability later in your profile.")
                        .font(AppFonts.caption())
                        .foregroundColor(.stackSecondaryText)
                        .multilineTextAlignment(.center)

                    Spacer(minLength: 40)
                }
            }
        }
    }

    @ViewBuilder
    private func formField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.stackInputIcon)
            TextField(placeholder, text: text)
                .font(.system(size: 16))
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(AppConstants.buttonCornerRadius)
    }

    /// Strips control characters (tabs, newlines, zero-width joiners, etc.)
    /// from user input that is meant to be a single-line name or username.
    private func sanitized(_ input: String) -> String {
        input.unicodeScalars.filter { !$0.properties.isDefaultIgnorableCodePoint && CharacterSet.controlCharacters.inverted.contains($0) }
            .reduce(into: "") { $0.unicodeScalars.append($1) }
    }

    private func submit() {
        errorMessage = nil

        let cleanFirst = sanitized(firstName).trimmingCharacters(in: .whitespaces)
        let cleanLast  = sanitized(lastName).trimmingCharacters(in: .whitespaces)
        let cleanUsername = sanitized(username).trimmingCharacters(in: .whitespaces)

        guard !cleanFirst.isEmpty else {
            errorMessage = "First name is required"
            return
        }
        guard cleanFirst.count <= 100 else {
            errorMessage = "First name is too long"
            return
        }
        guard !cleanLast.isEmpty else {
            errorMessage = "Last name is required"
            return
        }
        guard cleanLast.count <= 100 else {
            errorMessage = "Last name is too long"
            return
        }
        guard cleanUsername.count >= 3 else {
            errorMessage = "Username must be at least 3 characters"
            return
        }
        guard cleanUsername.count <= 100 else {
            errorMessage = "Username is too long"
            return
        }

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

                // Reload profile in app state
                if let userId = await AuthService.currentUserId() {
                    await appState.loadProfile(userId: userId)
                }
            } catch {
                let message = "\(error)"
                if message.lowercased().contains("username") || message.contains("duplicate") || message.contains("unique") || message.contains("23505") || message.contains("users_username_key") {
                    errorMessage = "That username is taken. Try another one."
                } else {
                    let taken = (try? await ProfileService.isUsernameTaken(username)) ?? false
                    if taken {
                        errorMessage = "That username is taken. Try another one."
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
