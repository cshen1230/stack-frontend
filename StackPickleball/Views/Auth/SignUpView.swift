import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AuthViewModel()
    @State private var confirmPassword = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.white, .stackLoginGradientEnd],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Header
                VStack(spacing: 8) {
                    Text("Create Account")
                        .font(AppFonts.pageTitle())
                        .foregroundColor(.stackGreen)

                    Text("Join the pickleball community")
                        .font(AppFonts.headline())
                        .foregroundColor(.stackSecondaryText)
                }

                Spacer()

                if viewModel.signUpSucceeded {
                    // Success state — clear instructions + way back
                    VStack(spacing: 20) {
                        Image(systemName: "envelope.badge.shield.half.filled")
                            .font(.system(size: 44))
                            .foregroundColor(.stackGreen)

                        Text("Check your email")
                            .font(AppFonts.sectionTitle())
                            .foregroundColor(.primary)

                        Text("We sent a confirmation link to **\(viewModel.email)**. Tap it, then come back and sign in.")
                            .font(AppFonts.body())
                            .foregroundColor(.stackSecondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)

                        Button(action: { dismiss() }) {
                            Text("Back to Sign In")
                                .font(AppFonts.headline())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Color.stackGreen)
                                .cornerRadius(AppConstants.buttonCornerRadius)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    // Input fields
                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope")
                                .font(AppFonts.body())
                                .foregroundColor(.stackInputIcon)
                            TextField("Email", text: $viewModel.email)
                                .font(AppFonts.body())
                                .textContentType(.emailAddress)
                                #if os(iOS)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                #endif
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(AppConstants.buttonCornerRadius)

                        HStack(spacing: 12) {
                            Image(systemName: "lock")
                                .font(AppFonts.body())
                                .foregroundColor(.stackInputIcon)
                            SecureField("Password", text: $viewModel.password)
                                .font(AppFonts.body())
                                .textContentType(.newPassword)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(AppConstants.buttonCornerRadius)

                        HStack(spacing: 12) {
                            Image(systemName: "lock")
                                .font(AppFonts.body())
                                .foregroundColor(.stackInputIcon)
                            SecureField("Confirm Password", text: $confirmPassword)
                                .font(AppFonts.body())
                                .textContentType(.newPassword)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(AppConstants.buttonCornerRadius)
                    }
                    .padding(.horizontal, 24)

                    // Error message
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(AppFonts.callout())
                            .foregroundColor(.red)
                            .padding(.horizontal, 24)
                    }

                    // Sign up button
                    Button(action: {
                        if viewModel.password != confirmPassword {
                            viewModel.errorMessage = "Passwords do not match"
                            return
                        }
                        Task {
                            await viewModel.signUp()
                        }
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Color.stackGreen)
                                .cornerRadius(AppConstants.buttonCornerRadius)
                        } else {
                            Text("Sign Up")
                                .font(AppFonts.headline())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Color.stackGreen)
                                .cornerRadius(AppConstants.buttonCornerRadius)
                        }
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .padding(.horizontal, 24)
                    .disabled(viewModel.isLoading)
                }

                // Back to login link
                if !viewModel.signUpSucceeded {
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundColor(.stackSecondaryText)
                        Button("Sign In") {
                            dismiss()
                        }
                        .foregroundColor(.stackGreen)
                        .fontWeight(.semibold)
                    }
                    .font(AppFonts.body())
                }

                Spacer()
            }
        }
        .animation(Motion.transition, value: viewModel.signUpSucceeded)
    }
}

#Preview {
    SignUpView()
        .environment(AppState())
}
