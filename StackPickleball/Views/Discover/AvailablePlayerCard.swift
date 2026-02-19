import SwiftUI

struct AvailablePlayerCard: View {
    let player: AvailablePlayer

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Avatar + green dot
            HStack(spacing: 10) {
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

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.displayName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if let rating = player.duprRating {
                        Text("DUPR \(String(format: "%.1f", rating))")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.stackDUPRBadge)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.stackBadgeBg)
                            .cornerRadius(4)
                    }
                }
            }

            if let note = player.note, !note.isEmpty {
                Text(note)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            // Bottom row: format chip + time
            HStack(spacing: 6) {
                if let format = player.preferredFormat {
                    Text(format.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(format.accentColor)
                        .cornerRadius(6)
                }

                Spacer(minLength: 0)

                Text(relativeTime(until: player.availableUntil))
                    .font(.system(size: 11))
                    .foregroundColor(.stackTimestamp)
            }
        }
        .padding(12)
        .frame(width: 164, height: 160)
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

    private func relativeTime(until date: Date) -> String {
        let remaining = date.timeIntervalSinceNow
        if remaining <= 0 { return "Expiring" }
        let hours = Int(remaining / 3600)
        let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 {
            return "\(hours)h \(minutes)m left"
        }
        return "\(minutes)m left"
    }
}
