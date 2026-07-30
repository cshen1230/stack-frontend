import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(DeepLinkRouter.self) private var deepLinkRouter
    @EnvironmentObject private var locationManager: LocationManager
    @State private var viewModel = HomeViewModel()
    @State private var selectedGame: Game?
    @State private var showingCreateGame = false
    @State private var showingReadyToPlay = false
    @State private var showingMap = false
    @State private var expandedGameId: UUID?
    @State private var selectedReadyFriend: ReadyFriend?
    @State private var createdSessionInfo: CreatedSessionInfo?
    @State private var showingAddFriends = false

    /// Drives the "Now" vs "at 1:45 PM" labels, so a window that opens while the user is
    /// looking at the screen starts reading as live without a reload.
    @State private var now = Date()
    private let clock = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private let distanceOptions: [Double] = [5, 10, 20, 50]
    private var currentUserId: UUID? { appState.currentUser?.id }

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.isLoading && viewModel.nearbyGames.isEmpty && viewModel.readyFriends.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)
                } else {
                    VStack(spacing: 20) {
                        // Ready to Play banner
                        readyToPlayBanner
                            .padding(.horizontal, 16)

                        // Who's ready at what time today
                        if !viewModel.readyFriends.isEmpty {
                            readyTodaySection
                                .padding(.horizontal, 16)
                        }

                        // Smart match suggestion card
                        if !viewModel.readyFriends.isEmpty {
                            smartSuggestionCard
                                .padding(.horizontal, 16)
                        }

                        // Open Games Near You
                        if !viewModel.nearbyGames.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Open Games Near You")
                                    .font(.system(size: 18, weight: .bold))
                                    .padding(.horizontal, 16)

                                LazyVStack(spacing: 12) {
                                    ForEach(viewModel.nearbyGames) { game in
                                        GameCardView(
                                            game: game,
                                            isHost: game.creatorId == currentUserId,
                                            isJoined: viewModel.joinedGameIds.contains(game.id),
                                            avatarURLs: viewModel.participantAvatars[game.id] ?? [],
                                            isExpanded: expandedGameId == game.id,
                                            onTap: {
                                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                    expandedGameId = expandedGameId == game.id ? nil : game.id
                                                }
                                            },
                                            onJoin: {
                                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                    expandedGameId = nil
                                                }
                                                Task { await viewModel.rsvpToGame(game) }
                                            },
                                            onView: {
                                                selectedGame = game
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        // Quick Actions
                        HStack(spacing: 12) {
                            Button {
                                showingCreateGame = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 15))
                                    Text("Create Game")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.stackGreen)
                                .cornerRadius(12)
                            }

                            Button {
                                appState.selectedTab = 1
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 15))
                                    Text("Browse Schedules")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(.stackGreen)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.stackGreen.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.stackGreen.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, 16)

                        // Empty state when no friends ready and no games
                        if viewModel.readyFriends.isEmpty && viewModel.nearbyGames.isEmpty {
                            EmptyStateView(
                                icon: "house",
                                title: "No Activity Nearby",
                                message: "No friends are ready and no open games nearby. Tap \"Ready to Play\" to let friends know you're available!"
                            )
                            .padding(.top, 20)
                        }
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 16)
                }
            }
            // Floating Map button
            .overlay(alignment: .bottom) {
                if !viewModel.nearbyGames.isEmpty {
                    Button {
                        showingMap = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Map")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.stackGreen)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    }
                    .padding(.bottom, 16)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.stackBackground)
            .navigationTitle("Home")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(distanceOptions, id: \.self) { dist in
                            Button {
                                viewModel.selectedDistance = dist
                                Task {
                                    await viewModel.loadHome(
                                        currentUserId: currentUserId,
                                        lat: locationManager.latitude,
                                        lng: locationManager.longitude
                                    )
                                }
                            } label: {
                                HStack {
                                    Text("\(Int(dist)) mi")
                                    if viewModel.selectedDistance == dist {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "location.circle")
                                .font(.system(size: 17))
                            Text("\(Int(viewModel.selectedDistance)) mi")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.primary)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showingAddFriends = true
                        } label: {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.primary)
                        }

                        Button {
                            showingCreateGame = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .task(id: currentUserId) {
                await viewModel.loadHome(
                    currentUserId: currentUserId,
                    lat: locationManager.latitude,
                    lng: locationManager.longitude
                )
            }
            .onReceive(clock) { now = $0 }
            .refreshable {
                await viewModel.loadHome(
                    currentUserId: currentUserId,
                    lat: locationManager.latitude,
                    lng: locationManager.longitude
                )
            }
            .navigationDestination(item: $selectedGame) { game in
                if game.sessionType == .roundRobin {
                    RoundRobinDetailView(game: game, isHost: game.creatorId == currentUserId)
                } else {
                    GameDetailView(game: game, isHost: game.creatorId == currentUserId)
                }
            }
            .sheet(isPresented: $showingCreateGame) {
                DayPlannerView(readyFriends: viewModel.readyFriends) { info in
                    showingCreateGame = false
                    createdSessionInfo = info
                    Task {
                        await viewModel.loadHome(
                            currentUserId: currentUserId,
                            lat: locationManager.latitude,
                            lng: locationManager.longitude
                        )
                    }
                }
            }
            .sheet(isPresented: $showingReadyToPlay) {
                ReadyToPlaySheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingAddFriends) {
                NavigationStack {
                    FriendsView(initiallyShowSearch: true)
                }
            }
            .sheet(item: $selectedReadyFriend) { friend in
                ReadyFriendDetailSheet(
                    friend: friend,
                    onCreateGame: {
                        showingCreateGame = true
                    },
                    onInviteToGame: {
                        // Navigate to invite flow
                    }
                )
            }
            .fullScreenCover(isPresented: $showingMap) {
                SessionMapView(
                    games: viewModel.nearbyGames,
                    joinedGameIds: viewModel.joinedGameIds,
                    currentUserId: currentUserId,
                    userLatitude: locationManager.latitude,
                    userLongitude: locationManager.longitude,
                    onJoin: { game in
                        Task { await viewModel.rsvpToGame(game) }
                    },
                    onView: { game in
                        showingMap = false
                        selectedGame = game
                    }
                )
            }
            .errorAlert($viewModel.errorMessage)
            .overlay {
                if let game = viewModel.joinedGame {
                    JoinedSessionToast(game: game) {
                        viewModel.joinedGame = nil
                    }
                } else if let info = createdSessionInfo {
                    CreatedSessionToast(info: info) {
                        createdSessionInfo = nil
                    }
                }
            }
            .onChange(of: deepLinkRouter.pendingGameId) {
                if let gameId = deepLinkRouter.pendingGameId {
                    deepLinkRouter.pendingGameId = nil
                    Task {
                        do {
                            let game = try await GameService.fetchGame(gameId: gameId)
                            selectedGame = game
                        } catch {
                            viewModel.errorMessage = "Could not load session"
                        }
                    }
                }
            }
        }
    }

    // MARK: - Ready Today

    private var readyTodaySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("Ready Today")
                    .font(.system(size: 18, weight: .bold))
                Text("\(viewModel.readyFriends.count)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.stackGreen)
                    .clipShape(Circle())
            }
            .padding(.bottom, 6)

            ForEach(Array(viewModel.readyFriends.enumerated()), id: \.element.id) { index, friend in
                if index > 0 {
                    Divider().padding(.leading, 74)
                }
                ReadyTimeRow(friend: friend, now: now) {
                    selectedReadyFriend = friend
                }
            }
        }
    }

    // MARK: - Smart Suggestion Card

    @ViewBuilder
    private var smartSuggestionCard: some View {
        let readyNow = viewModel.friendsReadyNow(at: now)
        let message: String = {
            if readyNow.count >= 2 {
                return "\(readyNow.count) friends are ready now — start a game?"
            } else if let friend = readyNow.first {
                let name = friend.firstName ?? friend.username ?? "A friend"
                return "\(name) is ready to play — invite them to a game?"
            } else if let next = viewModel.readyFriends.first {
                // Nobody yet, but someone's window opens later today.
                let name = next.firstName ?? next.username ?? "A friend"
                return "\(name) is ready at \(next.startLabel(at: now)) — line up a game?"
            }
            return ""
        }()

        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(message)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button {
                showingCreateGame = true
            } label: {
                Text("Create Game")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.stackGreen)
                    .cornerRadius(8)
            }
        }
        .padding(14)
        .background(Color.stackCardWhite)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.stackGreen.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Ready to Play Banner

    /// Your window, plus your note if you left one.
    private func bannerSubtitle(for availability: AvailablePlayer, isNow: Bool, now: Date) -> String {
        let window = isNow ? "Until \(availability.endLabel)" : availability.windowLabel(at: now)
        if let note = availability.note, !note.isEmpty {
            return "\(window) · \(note)"
        }
        return window
    }

    @ViewBuilder
    private var readyToPlayBanner: some View {
        if let availability = viewModel.currentAvailability {
            // Broadcasting — but only say "ready" if the window has actually opened.
            let isNow = viewModel.isCurrentUserReadyNow(at: now)

            HStack(spacing: 12) {
                if isNow {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                } else {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(isNow ? "You're Ready to Play" : "Ready at \(availability.startLabel(at: now))")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)

                    Text(bannerSubtitle(for: availability, isNow: isNow, now: now))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    Task { await viewModel.stopReady() }
                } label: {
                    Text("Stop")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.stackGreen)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(8)
                }
            }
            .padding(16)
            .background(Color.stackGreen)
            .cornerRadius(16)
        } else {
            // Ready button
            Button {
                showingReadyToPlay = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Ready to Play")
                        .font(.system(size: 17, weight: .bold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(16)
                .background(Color.stackGreen)
                .cornerRadius(16)
            }
        }
    }
}

#Preview {
    HomeView()
        .environment(AppState())
        .environment(DeepLinkRouter())
        .environmentObject(LocationManager.shared)
}
