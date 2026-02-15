import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var locationManager: LocationManager

    @State private var firstName = ""
    @State private var middleName = ""
    @State private var lastName = ""
    @State private var username = ""
    @State private var duprRating = ""
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

                        // DUPR Rating
                        formField(icon: "trophy", placeholder: "DUPR Rating (e.g. 3.5)", text: $duprRating)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
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
        guard let rating = Double(duprRating), rating >= 1.0, rating <= 8.0 else {
            errorMessage = "Enter a valid DUPR rating (1.0 - 8.0)"
            return
        }

        isLoading = true
        Task {
            do {
                try await ProfileService.createProfile(
                    firstName: firstName.trimmingCharacters(in: .whitespaces),
                    lastName: lastName.trimmingCharacters(in: .whitespaces),
                    middleName: middleName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : middleName.trimmingCharacters(in: .whitespaces),
                    username: username,
                    duprRating: rating,
                    latitude: locationManager.latitude,
                    longitude: locationManager.longitude
                )
                // Reload profile in app state
                if let userId = await AuthService.currentUserId() {
                    await appState.loadProfile(userId: userId)
                }
            } catch {
                errorMessage = error.localizedDescription
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
