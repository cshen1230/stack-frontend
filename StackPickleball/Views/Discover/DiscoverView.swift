import SwiftUI

struct DiscoverView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var locationManager: LocationManager
    @State private var viewModel = DiscoverViewModel()
    @State private var selectedGame: Game?

    private var currentUserId: UUID? { appState.currentUser?.id }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                FilterBarView(
                    distance: $viewModel.selectedDistance,
                    onApply: {
                        Task {
                            await viewModel.loadGames(
                                lat: locationManager.latitude,
                                lng: locationManager.longitude,
                                currentUserId: currentUserId
                            )
                        }
                    }
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white)

                Divider()

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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.stackBackground)
            }
            .navigationTitle("Discover Sessions")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .task {
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
            .errorAlert($viewModel.errorMessage)
        }
    }
}

#Preview {
    DiscoverView()
        .environment(AppState())
        .environmentObject(LocationManager.shared)
}
