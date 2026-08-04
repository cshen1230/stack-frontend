import SwiftUI

struct CreateGameButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 58, height: 58)
                .background(Color.stackGreen)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.15), radius: AppConstants.shadowBlur, x: 0, y: AppConstants.shadowYOffset)
        }
    }
}

#Preview {
    CreateGameButton {
        // Preview action
    }
    .padding(40)
    .background(Color.stackBackground)
}
