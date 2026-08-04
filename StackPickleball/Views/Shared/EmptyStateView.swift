import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var buttonTitle: String? = nil
    var buttonAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56, weight: .light))
                .foregroundColor(.stackSecondaryText)

            Text(title)
                .font(AppFonts.sectionTitle())
                .foregroundColor(.primary)

            Text(message)
                .font(AppFonts.body())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let buttonTitle = buttonTitle, let buttonAction = buttonAction {
                Button(action: buttonAction) {
                    Text(buttonTitle)
                        .font(AppFonts.body())
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.stackGreen)
                        .cornerRadius(AppConstants.buttonCornerRadius)
                }
                .padding(.top, 8)
            }
        }
        .padding(AppConstants.sectionSpacing)
    }
}

#Preview {
    EmptyStateView(
        icon: "sportscourt",
        title: "No Games Found",
        message: "There are no games available right now. Create one to get started!",
        buttonTitle: "Create Game",
        buttonAction: {}
    )
}
