import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AuthViewModel()
    @State private var confirmPassword = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.white, Color(hex: "#F1F8E9")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Header
                VStack(spacing: 8) {
                    Text("Create Account")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color(hex: "#2D5016"))

                    Text("Join the pickleball community")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Input fields — email + password only (name/DUPR collected in onboarding)
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope")
                            .foregroundColor(.secondary)
                        TextField("Email", text: $viewModel.email)
                            .textContentType(.emailAddress)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            #endif
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#E0E0E0"), lineWidth: 1)
                    )

                    HStack(spacing: 12) {
                        Image(systemName: "lock")
                            .foregroundColor(.secondary)
                        SecureField("Password", text: $viewModel.password)
                            .textContentType(.newPassword)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#E0E0E0"), lineWidth: 1)
                    )

                    HStack(spacing: 12) {
                        Image(systemName: "lock")
                            .foregroundColor(.secondary)
                        SecureField("Confirm Password", text: $confirmPassword)
                            .textContentType(.newPassword)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#E0E0E0"), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 24)

                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .padding(.horizontal, 24)
                }

                // Sign up button
                Button(action: {
                    if viewModel.password != confirmPassword {
                        viewModel.errorMessage = "Passwords do not match"
                        return
                    }
                    Task { await viewModel.signUp() }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Sign Up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color(hex: "#2D5016"))
                .cornerRadius(12)
                .padding(.horizontal, 24)
                .disabled(viewModel.isLoading)

                // Back to login link
                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .foregroundColor(.secondary)
                    Button("Sign In") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#2D5016"))
                    .fontWeight(.semibold)
                }
                .font(.system(size: 16))

                Spacer()
            }
        }
    }
}

#Preview {
    SignUpView()
        .environment(AppState())
}
