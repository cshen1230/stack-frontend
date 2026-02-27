import SwiftUI

struct MySessionsView: View {
    @Binding var selectedTab: Int

    @Environment(AppState.self) private var appState
    @State private var navigationPath = NavigationPath()
    @State private var sessions: [Game] = []
    @State private var participantAvatars: [UUID: [String]] = [:]
    @State private var groupChatIds: [UUID: UUID] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var gameToLeave: Game?
    @State private var gameToDelete: Game?

    private var currentUserId: UUID? { appState.currentUser?.id }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if isLoading {
                    ProgressView()
                } else if sessions.isEmpty {
                    EmptyStateView(
                        icon: "calendar.badge.clock",
                        title: "No Active Sessions",
                        message: "Join a session from the Discover tab to get started!"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(sessions) { game in
                                NavigationLink(value: game) {
                                    SessionFlyerCard(
                                        game: game,
                                        avatarURLs: participantAvatars[game.id] ?? [],
                                        totalParticipants: game.spotsFilled,
                                        groupChatId: groupChatIds[game.id],
                                        onGroupChatTapped: {
                                            if let chatId = groupChatIds[game.id] {
                                                appState.pendingGroupChatId = chatId
                                            }
                                        }
                                    )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    if game.creatorId == currentUserId {
                                        Button(role: .destructive) {
                                            gameToDelete = game
                                        } label: {
                                            Label("Delete Session", systemImage: "trash")
                                        }
                                    } else {
                                        Button(role: .destructive) {
                                            gameToLeave = game
                                        } label: {
                                            Label("Leave Session", systemImage: "rectangle.portrait.and.arrow.right")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.stackBackground)
            .navigationTitle("Sessions")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .navigationDestination(for: Game.self) { game in
                if game.sessionType == .roundRobin {
                    RoundRobinDetailView(game: game, isHost: game.creatorId == currentUserId)
                } else {
                    SessionFlyerDetailView(game: game, isHost: game.creatorId == currentUserId)
                }
            }
            .task(id: currentUserId) {
                await loadSessions()
            }
            .onAppear {
                Task { await loadSessions() }
            }
            .refreshable {
                await loadSessions()
            }
            .onChange(of: selectedTab) {
                if selectedTab != 1 {
                    navigationPath = NavigationPath()
                }
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
            let gameIds = sessions.map(\.id)

            // Fetch avatars and group chat IDs concurrently
            async let fetchAvatars = GameService.participantAvatarsForGames(gameIds: gameIds)

            // Fetch group chat IDs for each session
            await withTaskGroup(of: (UUID, UUID?).self) { group in
                for session in sessions {
                    group.addTask {
                        let chat = try? await GroupChatService.groupChatForGame(gameId: session.id)
                        return (session.id, chat?.id)
                    }
                }
                for await (gameId, chatId) in group {
                    if let chatId {
                        groupChatIds[gameId] = chatId
                    }
                }
            }

            participantAvatars = (try? await fetchAvatars) ?? [:]
        } catch where error.isCancellation {
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
