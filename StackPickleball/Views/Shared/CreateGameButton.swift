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
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
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
