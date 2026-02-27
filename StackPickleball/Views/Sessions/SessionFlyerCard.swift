import SwiftUI

struct SessionFlyerCard: View {
    let game: Game
    let avatarURLs: [String]
    let totalParticipants: Int
    var groupChatId: UUID?
    var onGroupChatTapped: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: format badge + spots
            HStack {
                HStack(spacing: 6) {
                    Text(game.gameFormat.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.stackGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.stackBadgeBg)
                        .cornerRadius(8)

                    if game.friendsOnly {
                        HStack(spacing: 3) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                            Text("Friends Only")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(8)
                    }

                    if let sessionType = game.sessionType, sessionType == .roundRobin {
                        Text("Round Robin")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.12))
                            .cornerRadius(8)
                    }
                }

                Spacer()

                Text("\(game.spotsFilled)/\(game.spotsAvailable)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.stackSecondaryText)
            }

            // Session name
            Text(game.sessionName ?? game.creatorDisplayName + "'s Session")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(2)

            // Date & time
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 13))
                    .foregroundColor(.stackSecondaryText)
                (Text(game.gameDatetime, format: .dateTime.weekday(.abbreviated))
                + Text(", ")
                + Text(game.gameDatetime, format: .dateTime.month(.abbreviated).day())
                + Text(" at ")
                + Text(game.gameDatetime, format: .dateTime.hour().minute()))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }

            // Location
            if let location = game.locationName {
                HStack(spacing: 6) {
                    Image(systemName: "mappin")
                        .font(.system(size: 13))
                        .foregroundColor(.stackSecondaryText)
                    Text(location)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
            }

            // Bottom row: avatars + group chat button
            HStack {
                // Participant avatars (inline)
                HStack(spacing: -8) {
                    ForEach(Array(avatarURLs.prefix(5).enumerated()), id: \.offset) { _, url in
                        inlineAvatar(url: url)
                    }
                    let extraCount = totalParticipants - min(avatarURLs.count, 5)
                    if extraCount > 0 {
                        Text("+\(extraCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.stackCardWhite, lineWidth: 1.5))
                    }
                }

                Spacer()

                // Group Chat button
                if groupChatId != nil {
                    Button {
                        onGroupChatTapped?()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left.and.text.bubble.right")
                                .font(.system(size: 12))
                            Text("Group Chat")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.stackGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.stackGreen.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.stackCardWhite)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func inlineAvatar(url: String) -> some View {
        if let imageURL = URL(string: url) {
            AsyncImage(url: imageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.25))
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                    )
            }
            .frame(width: 28, height: 28)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.stackCardWhite, lineWidth: 1.5))
        }
    }
}
