import SwiftUI

struct LoginView: View {
    @State private var viewModel = AuthViewModel()
    @State private var showingSignUp = false

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
                    Image("StackLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .cornerRadius(22)

                    Text("Stack")
                        .font(.system(size: 42, weight: .bold)) // Branding size — intentionally not a token
                        .foregroundColor(.stackGreen)

                    Text("Find players. Schedule games.\nJust play.")
                        .font(AppFonts.headline())
                        .foregroundColor(.stackSecondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                Spacer()

                // Form
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope")
                            .font(AppFonts.body())
                            .foregroundColor(.stackInputIcon)
                        TextField("Email", text: $viewModel.email)
                            .font(AppFonts.body())
                            .foregroundColor(.primary)
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
                            .foregroundColor(.primary)
                            .textContentType(.password)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(AppConstants.buttonCornerRadius)
                }
                .padding(.horizontal, 24)
                .onChange(of: viewModel.email) { viewModel.errorMessage = nil }
                .onChange(of: viewModel.password) { viewModel.errorMessage = nil }

                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(AppFonts.callout())
                        .foregroundColor(.red)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                }

                // Sign In button
                Button(action: {
                    Task { await viewModel.signIn() }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.stackGreen)
                            .cornerRadius(AppConstants.buttonCornerRadius)
                    } else {
                        Text("Sign In")
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
                .padding(.top, 24)
                .disabled(viewModel.isLoading)

                // Sign up link
                HStack(spacing: 0) {
                    Text("Don't have an account?")
                        .foregroundColor(.stackSecondaryText)
                    Text(" Sign Up")
                        .foregroundColor(.stackGreen)
                        .fontWeight(.bold)
                        .onTapGesture {
                            showingSignUp = true
                        }
                }
                .font(AppFonts.body())
                .padding(.top, 20)

                Spacer()
            }
        }
        .sheet(isPresented: $showingSignUp) {
            SignUpView()
        }
    }
}

#Preview {
    LoginView()
        .environment(AppState())
}
