import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(DeepLinkRouter.self) private var deepLinkRouter
    @EnvironmentObject private var locationManager: LocationManager
    @State private var viewModel = HomeViewModel()
    @State private var selectedGame: Game?
    @State private var showingMap = false
    @State private var createdSessionInfo: CreatedSessionInfo?
    @State private var showingAddFriends = false
    /// Set by the hero's button or a suggestion chip; the planner picks it up and opens the
    /// draft, so every route to creating a game runs through the same sheet.
    @State private var requestedRange: ClosedRange<Date>?

    /// Ties each card to the screen it becomes, so the detail grows out of the card the user
    /// touched rather than sliding in from the edge with no stated origin.
    @Namespace private var cardTransition

    private var currentUserId: UUID? { appState.currentUser?.id }

    /// Time-of-day greeting.
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let firstName = appState.currentUser?.displayName.components(separatedBy: " ").first ?? ""
        let timeOfDay: String
        switch hour {
        case 0..<12: timeOfDay = "Good morning"
        case 12..<17: timeOfDay = "Good afternoon"
        default: timeOfDay = "Good evening"
        }
        return firstName.isEmpty ? timeOfDay : "\(timeOfDay), \(firstName)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.isLoading && viewModel.nearbyGames.isEmpty && viewModel.schedulesByWeekday.isEmpty {
                    VStack(spacing: AppConstants.sectionSpacing) {
                        SkeletonHero()
                        SkeletonPlanner()
                        SkeletonList(count: 2) { SkeletonCard() }
                            .padding(.horizontal, AppConstants.screenPadding)
                    }
                    .padding(.top, 10)
                } else {
                    VStack(spacing: AppConstants.sectionSpacing) {
                        // 1. GREETING + PRIMARY CTA
                        StartGameHero(
                            greeting: greeting,
                            suggestions: viewModel.suggestions,
                            isLoaded: !viewModel.isLoading,
                            onStart: { requestedRange = SessionSuggestion.defaultRange() },
                            onPick: { requestedRange = $0.range }
                        )

                        // 2. YOUR SCHEDULE
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Your schedule")
                                .font(AppFonts.sectionTitle())
                                .foregroundColor(.primary)
                                .padding(.horizontal, AppConstants.screenPadding)

                            DayPlannerBoard(
                                schedulesByWeekday: viewModel.schedulesByWeekday,
                                mySessions: viewModel.mySessions,
                                suggestedPlayTime: viewModel.suggestedPlayTime,
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
                                requestedRange: $requestedRange,
                                onAddFriends: { showingAddFriends = true },
                                onSessionTapped: { game in
                                    selectedGame = game
                                }
                            )
                        }

                        // 3. GAMES NEAR YOU
                        if !viewModel.nearbyGames.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Games near you")
                                        .font(AppFonts.sectionTitle())
                                        .foregroundColor(.primary)

                                    Spacer()

                                    Button {
                                        showingMap = true
                                    } label: {
                                        Image(systemName: "map")
                                            .font(.system(size: 17, weight: .medium))
                                            .foregroundColor(.stackSecondaryText)
                                    }
                                }
                                .padding(.horizontal, AppConstants.screenPadding)

                                LazyVStack(spacing: AppConstants.cardSpacing) {
                                    ForEach(viewModel.nearbyGames) { game in
                                        GameCardView(
                                            game: game,
                                            isHost: game.creatorId == currentUserId,
                                            isJoined: viewModel.joinedGameIds.contains(game.id),
                                            avatarURLs: viewModel.participantAvatars[game.id] ?? [],
                                            onJoin: {
                                                Task { await viewModel.rsvpToGame(game) }
                                            },
                                            onView: {
                                                selectedGame = game
                                            }
                                        )
                                        .growsInto(game.id, in: cardTransition)
                                    }
                                }
                                .padding(.horizontal, AppConstants.screenPadding)
                            }
                        }

                        // Empty state when no friends ready and no games
                        if viewModel.schedulesByWeekday.isEmpty && viewModel.nearbyGames.isEmpty {
                            EmptyStateView(
                                icon: "figure.pickleball",
                                title: "Nobody's playing yet",
                                message: "Add friends to see when they're free, or start a game anyway and invite people to it."
                            )
                            .padding(.top, 8)
                        }
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 20)
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
