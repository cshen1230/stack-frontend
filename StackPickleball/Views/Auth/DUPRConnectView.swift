import SwiftUI
import AuthenticationServices

struct DUPRConnectView: View {
    var onConnected: ((DUPRService.DUPRProfile) -> Void)?
    var onSkip: (() -> Void)?
    var allowSkip: Bool = false
    var isConnected: Bool = false

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 14) {
            if isConnected {
                // Connected state
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.stackGreen)
                    Text("DUPR Verified")
                        .font(AppFonts.body())
                        .fontWeight(.semibold)
                        .foregroundColor(.stackGreen)
                }
                .padding(.vertical, 4)
            } else {
                // Header
                VStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.stackGreen)

                    Text("Connect Your DUPR Account")
                        .font(AppFonts.headline())
                        .foregroundColor(.primary)

                    Text("Verify your rating for skill-matched games")
                        .font(AppFonts.callout())
                        .foregroundColor(.stackSecondaryText)
                        .multilineTextAlignment(.center)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(AppFonts.subheadline())
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                // Connect button
                Button(action: connectDUPR) {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "link")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Connect DUPR")
                                .font(AppFonts.body())
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.stackGreen)
                    .cornerRadius(AppConstants.buttonCornerRadius)
                }
                .disabled(isLoading)

                // Skip button
                if allowSkip {
                    Button(action: { onSkip?() }) {
                        Text("Skip for now")
                            .font(AppFonts.callout())
                            .fontWeight(.medium)
                            .foregroundColor(.stackSecondaryText)
                    }
                }
            }
        }
        .cardStyle()
    }

    private func connectDUPR() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let profile = try await DUPRService.fullConnectFlow()
                onConnected?(profile)
            } catch is CancellationError {
                // User cancelled the auth session
            } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
                // User cancelled the auth session
            } catch {
                errorMessage = error.userFacingMessage
            }
            isLoading = false
        }
    }
}
