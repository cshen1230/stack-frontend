import SwiftUI

struct DiscoverView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var locationManager: LocationManager
    @State private var viewModel = DiscoverViewModel()
    @State private var selectedGame: Game?
    @State private var showingCreateGame = false
    @State private var expandedGameId: UUID?
    @State private var showingMap = false

    private let distanceOptions: [Double] = [5, 10, 20, 50]
    private var currentUserId: UUID? { appState.currentUser?.id }

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading && viewModel.games.isEmpty {
                    ProgressView()
                } else if viewModel.games.isEmpty {
                    EmptyStateView(
                        icon: "sportscourt",
                        title: "No Sessions Found",
                        message: "There are no sessions available nearby. Create one to get started!"
                    )
                } else {
                    ScrollView {
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
                        .padding(.top, 10)
                    }
                }
            }
            // Floating Map button
            .overlay(alignment: .bottom) {
                if !viewModel.games.isEmpty {
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
            .navigationBarTitleDisplayMode(.large)
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

                ToolbarItem(placement: .topBarTrailing) {
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
                GameDetailView(game: game, isHost: game.creatorId == currentUserId)
            }
            .sheet(isPresented: $showingCreateGame) {
                CreateGameView()
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
}

#Preview {
    DiscoverView()
        .environment(AppState())
        .environmentObject(LocationManager.shared)
}
