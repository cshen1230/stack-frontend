import SwiftUI

struct SessionShareBubble: View {
    let message: GroupChatMessage
    let gameId: UUID
    let isFromCurrentUser: Bool

    @Environment(AppState.self) private var appState
    @State private var game: Game?
    @State private var isLoading = true

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isFromCurrentUser {
                Spacer(minLength: 32)
            } else {
                Text(String(message.users.firstName.prefix(1)))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.stackGreen.opacity(0.7)))
                    .padding(.top, 2)
            }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isFromCurrentUser {
                    Text(message.senderDisplayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.stackSecondaryText)
                }

                if isLoading {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                        .frame(width: 220, height: 100)
                        .overlay(ProgressView())
                } else if let game {
                    NavigationLink {
                        SessionFlyerDetailView(
                            game: game,
                            isHost: game.creatorId == appState.currentUser?.id
                        )
                    } label: {
                        miniSessionCard(game: game)
                    }
                } else {
                    Text(message.content)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .italic()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                }

                Text(message.createdAt, format: .dateTime.hour().minute())
                    .font(.system(size: 11))
                    .foregroundColor(.stackTimestamp)
            }

            if !isFromCurrentUser {
                Spacer(minLength: 32)
            }
        }
        .padding(.vertical, 4)
        .task {
            await loadGame()
        }
    }

    private func loadGame() async {
        do {
            game = try await GameService.fetchGame(gameId: gameId)
        } catch {
            // Game may have been deleted
        }
        isLoading = false
    }

    private func miniSessionCard(game: Game) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(game.gameFormat.displayName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.stackGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.stackBadgeBg)
                    .cornerRadius(6)

                Spacer()

                Text("\(game.spotsFilled)/\(game.spotsAvailable)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.stackSecondaryText)
            }

            Text(game.sessionName ?? game.creatorDisplayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)

            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 10))
                Text(game.gameDatetime, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.system(size: 11))
            }
            .foregroundColor(.stackSecondaryText)

            if let location = game.locationName {
                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.system(size: 10))
                    Text(location)
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
                .foregroundColor(.stackSecondaryText)
            }
        }
        .padding(12)
        .frame(width: 220, alignment: .leading)
        .background(Color.stackCardWhite)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.stackGreen.opacity(0.3), lineWidth: 1)
        )
    }
}
