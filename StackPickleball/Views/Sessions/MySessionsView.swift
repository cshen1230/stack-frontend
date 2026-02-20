import SwiftUI

struct MySessionsView: View {
    @Environment(AppState.self) private var appState
    @State private var sessions: [Game] = []
    @State private var lastMessages: [UUID: GameMessage] = [:]
    @State private var participantSummaries: [UUID: [ParticipantSummaryRow]] = [:]
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
                        let participants = participantSummaries[game.id] ?? []
                        let dmPartner = dmPartner(for: game, participants: participants)

                        ZStack {
                            NavigationLink(value: game) { EmptyView() }
                                .opacity(0)
                            SessionRow(
                                game: game,
                                lastMessage: lastMessages[game.id],
                                avatarURLs: participants.compactMap(\.users.avatarUrl),
                                totalParticipants: game.spotsFilled,
                                dmPartner: dmPartner
                            )
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
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.visible)
                        .alignmentGuide(.listRowSeparatorLeading) { d in d[.leading] }
                        .listRowBackground(Color.stackBackground)
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

    private func dmPartner(for game: Game, participants: [ParticipantSummaryRow]) -> DMPartner? {
        guard game.spotsAvailable == 2 else { return nil }
        guard let userId = currentUserId else { return nil }
        let other = participants.first { $0.userId != userId }
        return other.map { DMPartner(name: $0.displayName, avatarURL: $0.users.avatarUrl) }
    }

    private func loadSessions() async {
        guard let userId = currentUserId else { return }
        do {
            sessions = try await MessageService.myActiveSessions(userId: userId)
            let gameIds = sessions.map(\.id)

            // Fetch last messages and participant summaries concurrently
            async let fetchSummaries = GameService.participantSummariesForGames(gameIds: gameIds)

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

            participantSummaries = (try? await fetchSummaries) ?? [:]
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - DM Partner

struct DMPartner {
    let name: String
    let avatarURL: String?
}

// MARK: - Session Row

private struct SessionRow: View {
    let game: Game
    let lastMessage: GameMessage?
    let avatarURLs: [String]
    let totalParticipants: Int
    let dmPartner: DMPartner?

    private var isDM: Bool { dmPartner != nil }

    var body: some View {
        HStack(spacing: 12) {
            // Avatar: single circle for DMs, collage for group
            if let partner = dmPartner {
                singleAvatar(url: partner.avatarURL)
            } else {
                SessionAvatarCollage(
                    avatarURLs: avatarURLs,
                    totalParticipants: totalParticipants
                )
            }

            // Text content
            VStack(alignment: .leading, spacing: 3) {
                // Top line: name + timestamp
                HStack {
                    Text(dmPartner?.name ?? game.sessionName ?? game.creatorDisplayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    if let msg = lastMessage {
                        Text(relativeTime(from: msg.createdAt))
                            .font(.system(size: 12))
                            .foregroundColor(.stackTimestamp)
                    }
                }

                // Last message preview
                if let msg = lastMessage {
                    if isDM {
                        Text(msg.content)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("\(msg.users.firstName): \(msg.content)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Text("No messages yet — say hello!")
                        .font(.system(size: 14))
                        .foregroundColor(.stackTimestamp)
                        .italic()
                        .lineLimit(1)
                }

                // Bottom: Location · Time · Format
                HStack(spacing: 4) {
                    if let location = game.locationName {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin")
                                .font(.system(size: 10))
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
                .font(.system(size: 11))
                .foregroundColor(.stackTimestamp)
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func singleAvatar(url: String?) -> some View {
        Group {
            if let url, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.25))
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                        )
                }
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.25))
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    )
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())
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

// MARK: - Session Avatar Collage

private struct SessionAvatarCollage: View {
    let avatarURLs: [String]
    let totalParticipants: Int

    private var displayCount: Int { min(totalParticipants, 4) }
    private var overflow: Int { max(0, totalParticipants - 4) }

    private func positions(for count: Int) -> [(x: CGFloat, y: CGFloat, size: CGFloat)] {
        switch count {
        case 0, 1:
            return [(0, 0, 48)]
        case 2:
            return [
                (-7, -5, 32),
                (7, 5, 32),
            ]
        case 3:
            return [
                (0, -8, 28),
                (-9, 7, 26),
                (9, 7, 26),
            ]
        default:
            return [
                (-8, -8, 26),
                (8, -8, 26),
                (-8, 8, 26),
                (8, 8, 26),
            ]
        }
    }

    var body: some View {
        let pos = positions(for: displayCount)

        ZStack {
            ForEach(Array(0..<max(displayCount, 1)), id: \.self) { i in
                let url: String? = i < avatarURLs.count ? avatarURLs[i] : nil
                avatarCircle(url: url, size: pos[i].size)
                    .offset(x: pos[i].x, y: pos[i].y)
            }

            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.stackBackground, lineWidth: 1.5))
                    .offset(x: 18, y: 18)
            }
        }
        .frame(width: 54, height: 54)
    }

    @ViewBuilder
    private func avatarCircle(url: String?, size: CGFloat) -> some View {
        Group {
            if let url, let imageURL = URL(string: url) {
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
        .overlay(Circle().stroke(Color.stackBackground, lineWidth: 1.5))
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
