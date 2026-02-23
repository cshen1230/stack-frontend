import SwiftUI

struct AvailablePlayerCard: View {
    let player: AvailablePlayer

    var body: some View {
        HStack(spacing: 12) {
            // Avatar with green dot
            ZStack(alignment: .bottomTrailing) {
                if let urlStr = player.avatarUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        initialCircle
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                } else {
                    initialCircle
                }

                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
            }

            // Name, note, metadata
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(player.displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if let rating = player.duprRating {
                        Text("\(String(format: "%.1f", rating)) DUPR")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.stackDUPRBadge)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.stackBadgeBg)
                            .cornerRadius(4)
                    }
                }

                if let format = player.preferredFormat {
                    Text(format.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(format.accentColor)
                        .cornerRadius(6)
                }

                if let note = player.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.stackCardWhite)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black, lineWidth: 1)
        )
    }

    private var initialCircle: some View {
        Circle()
            .fill(Color.stackGreen.opacity(0.15))
            .frame(width: 48, height: 48)
            .overlay(
                Text(playerInitial)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.stackGreen)
            )
    }

    private var playerInitial: String {
        let name = player.firstName ?? player.username ?? "?"
        return String(name.prefix(1)).uppercased()
    }

}
