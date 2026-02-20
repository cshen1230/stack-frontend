import SwiftUI

struct MySessionsView: View {
    @Environment(AppState.self) private var appState
    @State private var sessions: [Game] = []
    @State private var lastMessages: [UUID: GameMessage] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var gameToLeave: Game?
    @State private var gameToDelete: Game?

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
                            SessionRow(game: game, lastMessage: lastMessages[game.id])
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if game.creatorId == currentUserId {
                                Button(role: .destructive) {
                                    gameToDelete = game
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            } else {
                                Button(role: .destructive) {
                                    gameToLeave = game
                                } label: {
                                    Label("Leave", systemImage: "rectangle.portrait.and.arrow.right")
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
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
            .alert("Leave Session?", isPresented: Binding(
                get: { gameToLeave != nil },
                set: { if !$0 { gameToLeave = nil } }
            )) {
                Button("Cancel", role: .cancel) { gameToLeave = nil }
                Button("Leave", role: .destructive) {
                    if let game = gameToLeave {
                        Task {
                            try? await GameService.cancelRsvp(gameId: game.id)
                            sessions.removeAll { $0.id == game.id }
                            gameToLeave = nil
                        }
                    }
                }
            } message: {
                Text("You will be removed from this session and its chat.")
            }
            .alert("Delete Session?", isPresented: Binding(
                get: { gameToDelete != nil },
                set: { if !$0 { gameToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) { gameToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let game = gameToDelete {
                        Task {
                            try? await GameService.deleteGame(gameId: game.id)
                            sessions.removeAll { $0.id == game.id }
                            gameToDelete = nil
                        }
                    }
                }
            } message: {
                Text("This will permanently delete the session for all participants.")
            }
        }
    }

    private func loadSessions() async {
        guard let userId = currentUserId else { return }
        do {
            sessions = try await MessageService.myActiveSessions(userId: userId)
            // Fetch last message for each session concurrently
            await withTaskGroup(of: (UUID, GameMessage?).self) { group in
                for session in sessions {
                    group.addTask {
                        let msg = try? await MessageService.lastMessage(gameId: session.id)
                        return (session.id, msg)
                    }
                }
                for await (gameId, msg) in group {
                    if let msg {
                        lastMessages[gameId] = msg
                    }
                }
            }
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
    let lastMessage: GameMessage?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top: Session name + last message preview
            HStack(alignment: .top) {
                // Chat icon
                ZStack {
                    Circle()
                        .fill(Color.stackGreen.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.stackGreen)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(game.sessionName ?? game.creatorDisplayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if let msg = lastMessage {
                        Text("\(msg.users.firstName): \(msg.content)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("No messages yet — say hello!")
                            .font(.system(size: 14))
                            .foregroundColor(.stackTimestamp)
                            .italic()
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                // Relative timestamp
                if let msg = lastMessage {
                    Text(relativeTime(from: msg.createdAt))
                        .font(.system(size: 12))
                        .foregroundColor(.stackTimestamp)
                }
            }

            // Bottom: Location · Time · Format
            HStack(spacing: 4) {
                if let location = game.locationName {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin")
                            .font(.system(size: 11))
                        Text(location)
                            .lineLimit(1)
                    }

                    Text("·")
                        .fontWeight(.bold)
                }

                Text(game.gameDatetime, format: .dateTime.month(.abbreviated).day().hour().minute())

                Text("·")
                    .fontWeight(.bold)

                Text(game.gameFormat.displayName)
            }
            .font(.system(size: 12))
            .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.stackCardWhite)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.stackBorder, lineWidth: 1)
        )
    }

    private func relativeTime(from date: Date) -> String {
        let elapsed = Date().timeIntervalSince(date)
        if elapsed < 60 { return "now" }
        let minutes = Int(elapsed / 60)
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = Int(elapsed / 3600)
        if hours < 24 { return "\(hours)h ago" }
        let days = Int(elapsed / 86400)
        return "\(days)d ago"
    }
}
