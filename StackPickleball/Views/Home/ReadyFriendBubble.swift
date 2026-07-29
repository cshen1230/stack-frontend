import SwiftUI

struct ReadyFriendBubble: View {
    let friend: ReadyFriend
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                // Avatar with green ring
                ZStack {
                    Circle()
                        .stroke(Color.stackGreen, lineWidth: 3)
                        .frame(width: 58, height: 58)

                    if let urlStr = friend.avatarUrl, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            initialCircle
                        }
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())
                    } else {
                        initialCircle
                    }
                }

                Text(friend.firstName ?? friend.username ?? "?")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(width: 60)
            }
        }
        .buttonStyle(.plain)
    }

    private var initialCircle: some View {
        Circle()
            .fill(Color.stackGreen)
            .frame(width: 52, height: 52)
            .overlay(
                Text(friendInitial)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            )
    }

    private var friendInitial: String {
        let name = friend.firstName ?? friend.username ?? "?"
        return String(name.prefix(1)).uppercased()
    }
}
