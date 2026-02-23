import SwiftUI

struct DiscoverView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var locationManager: LocationManager
    @State private var viewModel = DiscoverViewModel()
    @State private var selectedGame: Game?
    @State private var showingCreateGame = false
    @State private var expandedGameId: UUID?
    @State private var showingMap = false
    @State private var showingAvailability = false

    private let distanceOptions: [Double] = [5, 10, 20, 50]
    private var currentUserId: UUID? { appState.currentUser?.id }

    private var showPlayers: Bool {
        viewModel.discoverFilter == .both || viewModel.discoverFilter == .players
    }

    private var showSessions: Bool {
        viewModel.discoverFilter == .both || viewModel.discoverFilter == .sessions
    }

    private var isContentEmpty: Bool {
        let noPlayers = !showPlayers || viewModel.availablePlayers.isEmpty
        let noSessions = !showSessions || viewModel.games.isEmpty
        return noPlayers && noSessions
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.isLoading && viewModel.games.isEmpty && viewModel.availablePlayers.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)
                } else if isContentEmpty {
                    EmptyStateView(
                        icon: emptyStateIcon,
                        title: emptyStateTitle,
                        message: emptyStateMessage
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    VStack(spacing: 16) {
                        // Available Players
                        if showPlayers && !viewModel.availablePlayers.isEmpty {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.availablePlayers) { player in
                                    AvailablePlayerCard(player: player)
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // Game sessions list
                        if showSessions && !viewModel.games.isEmpty {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.games) { game in
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
                    .padding(.top, 10)
                }
            }
            // Filter chips
            .safeAreaInset(edge: .top) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DiscoverFilter.allCases, id: \.self) { filter in
                            Button {
                                viewModel.discoverFilter = filter
                            } label: {
                                Text(filter.rawValue)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(viewModel.discoverFilter == filter ? .white : .primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(viewModel.discoverFilter == filter ? Color.stackGreen : Color.white)
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(viewModel.discoverFilter == filter ? Color.clear : Color.stackBorder, lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(Color.stackBackground)
            }
            // Floating Map button
            .overlay(alignment: .bottom) {
                if showSessions && !viewModel.games.isEmpty {
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
            .navigationTitle("Discover")
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
                                    await viewModel.loadGames(
                                        lat: locationManager.latitude,
                                        lng: locationManager.longitude,
                                        currentUserId: currentUserId
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

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingAvailability = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.primary)
                            if viewModel.isCurrentUserAvailable {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 2, y: -2)
                            }
                        }
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
            .task(id: currentUserId) {
                await viewModel.loadGames(
                    lat: locationManager.latitude,
                    lng: locationManager.longitude,
                    currentUserId: currentUserId
                )
            }
            .refreshable {
                await viewModel.loadGames(
                    lat: locationManager.latitude,
                    lng: locationManager.longitude,
                    currentUserId: currentUserId
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
                SessionTypePickerView()
            }
            .sheet(isPresented: $showingAvailability) {
                SetAvailabilitySheet(viewModel: viewModel)
            }
            .fullScreenCover(isPresented: $showingMap) {
                SessionMapView(
                    games: viewModel.games,
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
        }
    }

    // MARK: - Empty State Helpers

    private var emptyStateIcon: String {
        switch viewModel.discoverFilter {
        case .both: return "sportscourt"
        case .sessions: return "sportscourt"
        case .players: return "person.2"
        }
    }

    private var emptyStateTitle: String {
        switch viewModel.discoverFilter {
        case .both: return "No Sessions Found"
        case .sessions: return "No Sessions Found"
        case .players: return "No Available Players"
        }
    }

    private var emptyStateMessage: String {
        switch viewModel.discoverFilter {
        case .both: return "There are no sessions available nearby. Create one to get started!"
        case .sessions: return "There are no sessions available nearby. Create one to get started!"
        case .players: return "No players are available nearby right now. Set yourself as available to get started!"
        }
    }
}

#Preview {
    DiscoverView()
        .environment(AppState())
        .environmentObject(LocationManager.shared)
}
