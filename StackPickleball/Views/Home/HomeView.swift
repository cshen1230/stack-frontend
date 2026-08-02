import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(DeepLinkRouter.self) private var deepLinkRouter
    @EnvironmentObject private var locationManager: LocationManager
    @State private var viewModel = HomeViewModel()
    @State private var selectedGame: Game?
    @State private var showingMap = false
    @State private var expandedGameId: UUID?
    @State private var createdSessionInfo: CreatedSessionInfo?
    @State private var showingAddFriends = false

    /// Ties each card to the screen it becomes, so the detail grows out of the card the user
    /// touched rather than sliding in from the edge with no stated origin.
    @Namespace private var cardTransition

    private var currentUserId: UUID? { appState.currentUser?.id }

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.isLoading && viewModel.nearbyGames.isEmpty && viewModel.schedulesByWeekday.isEmpty {
                    VStack(spacing: 20) {
                        SkeletonPlanner()
                        SkeletonList(count: 2) { SkeletonCard() }
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, 10)
                } else {
                    VStack(spacing: 20) {
                        // Who's free, and where you plan a session — same calendar.
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Plan a Session")
                                .font(.system(size: 18, weight: .bold))
                                .padding(.horizontal, 16)

                            DayPlannerBoard(
                                schedulesByWeekday: viewModel.schedulesByWeekday,
                                mySessions: viewModel.mySessions,
                                onCreated: { info in
                                    createdSessionInfo = info
                                    Task {
                                        await viewModel.loadHome(
                                            currentUserId: currentUserId,
                                            lat: locationManager.latitude,
                                            lng: locationManager.longitude
                                        )
                                    }
                                },
                                onSessionTapped: { game in
                                    selectedGame = game
                                }
                            )
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
                                                withAnimation(Motion.state) {
                                                    expandedGameId = expandedGameId == game.id ? nil : game.id
                                                }
                                            },
                                            onJoin: {
                                                withAnimation(Motion.state) {
                                                    expandedGameId = nil
                                                }
                                                Task { await viewModel.rsvpToGame(game) }
                                            },
                                            onView: {
                                                selectedGame = game
                                            }
                                        )
                                        .growsInto(game.id, in: cardTransition)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        // Quick Actions
                        HStack(spacing: 12) {
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
                        if viewModel.schedulesByWeekday.isEmpty && viewModel.nearbyGames.isEmpty {
                            EmptyStateView(
                                icon: "house",
                                title: "No Activity Nearby",
                                message: "No friends have posted times and there are no open games nearby. Add friends, or block out a slot above to start a session."
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddFriends = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
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
            .refreshable {
                await viewModel.loadHome(
                    currentUserId: currentUserId,
                    lat: locationManager.latitude,
                    lng: locationManager.longitude
                )
            }
            .navigationDestination(item: $selectedGame) { game in
                Group {
                    if game.sessionType == .roundRobin {
                        RoundRobinDetailView(game: game, isHost: game.creatorId == currentUserId)
                    } else {
                        GameDetailView(game: game, isHost: game.creatorId == currentUserId)
                    }
                }
                .grownFrom(game.id, in: cardTransition)
            }
            .sheet(isPresented: $showingAddFriends) {
                NavigationStack {
                    FriendsView(initiallyShowSearch: true)
                }
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

}

#Preview {
    HomeView()
        .environment(AppState())
        .environment(DeepLinkRouter())
        .environmentObject(LocationManager.shared)
}
