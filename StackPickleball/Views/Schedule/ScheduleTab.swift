import SwiftUI

/// "My Schedule" used to live here too, but a standing weekly pattern is a set-and-forget
/// setting, not a place you visit — it moved to Profile so this tab is only about what's
/// actually happening.
enum ScheduleSection: String, CaseIterable {
    case sessions = "Sessions"
    case friends = "Friends"
}

struct ScheduleTab: View {
    @Binding var selectedTab: Int

    @Environment(AppState.self) private var appState
    @State private var viewModel = ScheduleViewModel()
    @State private var navigationPath = NavigationPath()
    @State private var selectedSection: ScheduleSection = .sessions
    @State private var showingCreateGame = false
    @State private var createdSessionInfo: CreatedSessionInfo?
    @State private var gameToLeave: Game?
    @State private var gameToDelete: Game?

    private var currentUserId: UUID? { appState.currentUser?.id }

    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Segmented picker
                Picker("Section", selection: $selectedSection) {
                    ForEach(ScheduleSection.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                // Content
                Group {
                    switch selectedSection {
                    case .sessions:
                        sessionsSection
                    case .friends:
                        friendsSection
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.stackBackground)
            .navigationTitle("Schedule")
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
                guard let userId = currentUserId else { return }
                await viewModel.loadSchedule(userId: userId)
            }
            .refreshable {
                guard let userId = currentUserId else { return }
                await viewModel.loadSchedule(userId: userId)
            }
            .onChange(of: selectedTab) {
                if selectedTab != 1 {
                    navigationPath = NavigationPath()
                }
            }
            .onChange(of: selectedSection) {
                if selectedSection == .friends, let userId = currentUserId {
                    Task { await viewModel.loadFriendSchedules(userId: userId) }
                }
            }
            .sheet(isPresented: $showingCreateGame) {
                DayPlannerView(readyFriends: viewModel.friendsReady) { info in
                    showingCreateGame = false
                    createdSessionInfo = info
                    if let userId = currentUserId {
                        Task { await viewModel.loadUpcomingSessions(userId: userId) }
                    }
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
                            viewModel.upcomingSessions.removeAll { $0.id == game.id }
                            gameToLeave = nil
                        }
                    }
                }
            } message: {
                Text("You will be removed from this session and its community.")
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
                            viewModel.upcomingSessions.removeAll { $0.id == game.id }
                            gameToDelete = nil
                        }
                    }
                }
            } message: {
                Text("This will permanently delete the session for all participants.")
            }
            .errorAlert($viewModel.errorMessage)
            .overlay {
                if let info = createdSessionInfo {
                    CreatedSessionToast(info: info) {
                        createdSessionInfo = nil
                    }
                }
            }
        }
    }

    // MARK: - Sessions Section

    @ViewBuilder
    private var sessionsSection: some View {
        if viewModel.isLoading && viewModel.upcomingSessions.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.upcomingSessions.isEmpty {
            VStack(spacing: 12) {
                EmptyStateView(
                    icon: "calendar.badge.clock",
                    title: "No Active Sessions",
                    message: "Join or create a session to get started!"
                )
                Button {
                    showingCreateGame = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 15))
                        Text("Create Game")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.stackGreen)
                    .cornerRadius(12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.upcomingSessions) { game in
                        NavigationLink(value: game) {
                            SessionFlyerCard(
                                game: game,
                                avatarURLs: viewModel.participantAvatars[game.id] ?? [],
                                totalParticipants: game.spotsFilled,
                                groupChatId: viewModel.groupChatIds[game.id],
                                onGroupChatTapped: {
                                    if let chatId = viewModel.groupChatIds[game.id] {
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

    // MARK: - Friends Section

    @ViewBuilder
    private var friendsSection: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Day picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { day in
                            Button {
                                viewModel.selectedDayOfWeek = day
                                if let userId = currentUserId {
                                    Task { await viewModel.loadFriendSchedules(userId: userId) }
                                }
                            } label: {
                                Text(dayNames[day])
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(viewModel.selectedDayOfWeek == day ? .white : .primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(viewModel.selectedDayOfWeek == day ? Color.stackGreen : Color.stackBackground)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(viewModel.selectedDayOfWeek == day ? Color.clear : Color.stackBorder, lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Ready Now section
                if !viewModel.friendsReady.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Ready Now")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .padding(.horizontal, 16)

                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.friendsReady) { friend in
                                ReadyFriendCard(
                                    friend: friend,
                                    onCreateGame: {
                                        showingCreateGame = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                // Usually Available section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Usually Available on \(dayNames[viewModel.selectedDayOfWeek])")
                        .font(.system(size: 16, weight: .bold))
                        .padding(.horizontal, 16)

                    if viewModel.friendSchedules.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "person.2")
                                .font(.system(size: 24))
                                .foregroundColor(.stackSecondaryText)
                            Text("No friends have availability set for \(dayNames[viewModel.selectedDayOfWeek])")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.friendSchedules) { schedule in
                                FriendScheduleCard(schedule: schedule)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                // Create game button when friends are shown
                if !viewModel.friendsReady.isEmpty || !viewModel.friendSchedules.isEmpty {
                    Button {
                        showingCreateGame = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 15))
                            Text("Create Game")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.stackGreen)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Helpers

    private func formatTimeRange(start: String, end: String) -> String {
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "h:mm a"
        let formats = ["HH:mm:ss", "HH:mm"]

        func parseTime(_ str: String) -> Date? {
            for fmt in formats {
                let f = DateFormatter()
                f.dateFormat = fmt
                if let d = f.date(from: str) { return d }
            }
            return nil
        }

        guard let startDate = parseTime(start),
              let endDate = parseTime(end) else {
            return "\(start) - \(end)"
        }
        return "\(displayFormatter.string(from: startDate)) - \(displayFormatter.string(from: endDate))"
    }
}
