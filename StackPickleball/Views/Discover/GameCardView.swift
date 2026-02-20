import SwiftUI

struct GameCardView: View {
    let game: Game
    let isHost: Bool
    let isJoined: Bool
    let avatarURLs: [String]
    let isExpanded: Bool
    let onTap: () -> Void
    let onJoin: () -> Void
    let onView: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            // Left: Session info
            VStack(alignment: .leading, spacing: 4) {
                if isHost {
                    Text("Host")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .cornerRadius(4)
                }

                Text(game.sessionName ?? game.creatorDisplayName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(game.spotsFilled)/\(game.spotsAvailable) spots")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    if let min = game.skillLevelMin, let max = game.skillLevelMax {
                        Text("DUPR \(String(format: "%.1f", min))–\(String(format: "%.1f", max))")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 4) {
                        Text(game.gameFormat.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)

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
            }

            Spacer(minLength: 12)

            // Right: Avatars or action buttons (swap in place)
            ZStack {
                // Avatar cluster — visible when collapsed
                AvatarClusterView(
                    avatarURLs: avatarURLs,
                    totalParticipants: game.spotsFilled
                )
                .opacity(isExpanded ? 0 : 1)
                .scaleEffect(isExpanded ? 0.6 : 1)

                // Action buttons — visible when expanded
                VStack(spacing: 8) {
                    Button(action: onView) {
                        Text("View")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.stackGreen)
                            .frame(width: 80)
                            .padding(.vertical, 10)
                            .background(Color.stackGreen.opacity(0.15))
                            .cornerRadius(10)
                    }

                    if !isJoined {
                        if game.spotsRemaining > 0 {
                            Button(action: onJoin) {
                                Text("Join")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 80)
                                    .padding(.vertical, 10)
                                    .background(Color.stackGreen)
                                    .cornerRadius(10)
                            }
                        } else {
                            Text("Full")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(width: 80)
                                .padding(.vertical, 10)
                        }
                    }
                }
                .opacity(isExpanded ? 1 : 0)
                .scaleEffect(isExpanded ? 1 : 0.6)
            }
            .frame(width: 90, height: 80)
        }
        .padding(16)
        .background(Color.stackCardWhite)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black, lineWidth: 1)
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(game.gameFormat.accentColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.black, lineWidth: 1)
                )
                .offset(x: isExpanded ? 3 : 0, y: isExpanded ? 4 : 0)
                .opacity(isExpanded ? 1 : 0)
        )
        .scaleEffect(isExpanded ? 1.02 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
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
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
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
        .overlay(Circle().stroke(Color.white, lineWidth: 2))
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
