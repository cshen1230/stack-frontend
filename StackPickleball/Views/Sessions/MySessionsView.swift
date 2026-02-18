import SwiftUI

struct MySessionsView: View {
    @Environment(AppState.self) private var appState
    @State private var sessions: [Game] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var currentUserId: UUID? { appState.currentUser?.id }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if sessions.isEmpty {
                    EmptyStateView(
                        icon: "bubble.left.and.bubble.right",
                        title: "No Active Sessions",
                        message: "Join a session from the Discover tab to start chatting!"
                    )
                } else {
                    List(sessions) { game in
                        NavigationLink(value: game) {
                            SessionRow(game: game)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.stackBackground)
            .navigationTitle("Sessions")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .navigationDestination(for: Game.self) { game in
                GameChatView(game: game, currentUserId: currentUserId ?? UUID())
            }
            .task(id: currentUserId) {
                await loadSessions()
            }
            .refreshable {
                await loadSessions()
            }
        }
    }

    private func loadSessions() async {
        guard let userId = currentUserId else { return }
        do {
            sessions = try await MessageService.myActiveSessions(userId: userId)
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Session Row

private struct SessionRow: View {
    let game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(game.sessionName ?? game.creatorDisplayName)
                .font(.system(size: 16, weight: .semibold))

            HStack(spacing: 8) {
                Text(game.gameFormat.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.stackGreen)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.stackGreen.opacity(0.15))
                    .cornerRadius(4)

                Text(game.gameDatetime, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            if let location = game.locationName {
                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.system(size: 11))
                    Text(location)
                        .font(.system(size: 13))
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
