import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.white, .stackLoginGradientEnd],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Branding
                VStack(spacing: 16) {
                    // App icon
                    Image("StackLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .cornerRadius(22)

                    Text("Stack")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.stackGreen)

                    Text("Your Pickleball Community")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.stackSecondaryText)
                }

                Spacer()

                // Form
                VStack(spacing: 14) {
                    // Email field
                    HStack(spacing: 12) {
                        Image(systemName: "envelope")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "#9CA3AF"))
                        TextField("Email", text: $authViewModel.email)
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                            .textContentType(.emailAddress)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            #endif
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(hex: "#E5E7EB"), lineWidth: 1)
                    )
                    .colorScheme(.light)

                    // Password field
                    HStack(spacing: 12) {
                        Image(systemName: "lock")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "#9CA3AF"))
                        SecureField("Password", text: $authViewModel.password)
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                            .textContentType(.password)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(hex: "#E5E7EB"), lineWidth: 1)
                    )
                    .colorScheme(.light)
                }
                .padding(.horizontal, 24)

                // Sign In button
                Button(action: {
                    Task {
                        await authViewModel.signIn()
                    }
                }) {
                    if authViewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.stackGreen)
                            .cornerRadius(14)
                    } else {
                        Text("Sign In")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.stackGreen)
                            .cornerRadius(14)
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .disabled(authViewModel.isLoading)

                // Sign up link
                HStack(spacing: 0) {
                    Text("Don't have an account?")
                        .foregroundColor(.stackSecondaryText)
                    Text(" Sign Up")
                        .foregroundColor(.stackGreen)
                        .fontWeight(.bold)
                        .onTapGesture {
                            // TODO: Navigate to sign up view
                        }
                }
                .font(.system(size: 16))
                .padding(.top, 20)

                Spacer()
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
