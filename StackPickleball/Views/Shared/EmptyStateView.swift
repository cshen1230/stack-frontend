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
                .font(.system(size: 64))
                .foregroundColor(Color(hex: "#757575"))

            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)

            Text(message)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let buttonTitle = buttonTitle, let buttonAction = buttonAction {
                Button(action: buttonAction) {
                    Text(buttonTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#2D5016"))
                        .cornerRadius(12)
                }
                .padding(.top, 8)
            }
        }
        .padding(32)
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
