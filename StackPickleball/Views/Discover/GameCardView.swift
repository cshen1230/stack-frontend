import SwiftUI

struct GameCardView: View {
    let game: Game
    let isHost: Bool
    let isJoined: Bool
    let avatarURLs: [String]
    let onJoin: () -> Void
    let onView: () -> Void

    var body: some View {
        Button(action: onView) {
            HStack(alignment: .center, spacing: 14) {
                // Left: Session info
                VStack(alignment: .leading, spacing: 4) {
                    if isHost {
                        Text("Host")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.stackGreen)
                    }

                    HStack(spacing: 5) {
                        if game.friendsOnly {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                        }
                        Text(game.sessionName ?? game.creatorDisplayName)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }

                    // Date and time — the most important info on a scheduling card
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                        (Text(game.gameDatetime, format: .dateTime.weekday(.abbreviated))
                        + Text(" ")
                        + Text(game.gameDatetime, format: .dateTime.hour().minute()))
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.stackSecondaryText)

                    HStack(spacing: 8) {
                        Text(game.gameFormat.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)

                        Text(game.balance.summary)
                            .font(.system(size: 13, weight: game.balance.wanted > 0 ? .semibold : .regular))
                            .foregroundColor(game.balance.wanted > 0 ? .stackGreen : .secondary)

                        if game.sessionType == .roundRobin {
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 9))
                                Text("RR")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.stackGreen)
                        }
                    }
                }

                Spacer(minLength: 8)

                // Right: Join button or status
                if isJoined || isHost {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.stackSecondaryText)
                } else if game.spotsRemaining > 0 {
                    Button(action: {
                        onJoin()
                    }) {
                        Text("Join")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .background(Color.stackGreen)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Full")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Avatar Cluster

struct AvatarClusterView: View {
    let avatarURLs: [String]
    let totalParticipants: Int

    private var displayCount: Int {
        min(totalParticipants, 4)
    }

    private var overflow: Int {
        max(0, totalParticipants - displayCount)
    }

    private func clusterPositions(for count: Int) -> [(x: CGFloat, y: CGFloat, size: CGFloat)] {
        switch count {
        case 0:
            return []
        case 1:
            return [(0, 0, 48)]
        case 2:
            return [
                (-10, -4, 44),
                (14, 6, 40),
            ]
        case 3:
            return [
                (-6, -12, 42),
                (18, -2, 38),
                (4, 18, 36),
            ]
        default:
            return [
                (-8, -14, 42),
                (20, -6, 38),
                (-12, 14, 36),
                (18, 18, 34),
            ]
        }
    }

    var body: some View {
        let pos = clusterPositions(for: displayCount)

        ZStack {
            ForEach(Array(0..<displayCount), id: \.self) { i in
                let url: String? = i < avatarURLs.count ? avatarURLs[i] : nil
                avatarCircle(url: url, size: pos[i].size)
                    .offset(x: pos[i].x, y: pos[i].y)
            }

            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                    .offset(x: 28, y: 24)
            }
        }
        .frame(width: 90, height: 80)
    }

    @ViewBuilder
    private func avatarCircle(url: String?, size: CGFloat) -> some View {
        Group {
            if let url = url, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    placeholderCircle(size: size)
                }
            } else {
                placeholderCircle(size: size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
    }

    private func placeholderCircle(size: CGFloat) -> some View {
        Circle()
            .fill(Color.gray.opacity(0.25))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.36))
                    .foregroundColor(.white)
            )
    }
}
