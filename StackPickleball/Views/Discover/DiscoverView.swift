import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @State private var viewModel = DiscoverViewModel()
    @State private var showingPlayerSearch = false

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
                                lng: locationManager.longitude
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
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.games.isEmpty {
                        EmptyStateView(
                            icon: "sportscourt",
                            title: "No Games Found",
                            message: "There are no games available nearby. Create one to get started!"
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.games) { game in
                                    GameCardView(game: game) {
                                        Task { await viewModel.rsvpToGame(game) }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                        }
                    }
                }
                .background(Color.stackBackground)
            }
            .navigationTitle("Discover Games")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: { showingPlayerSearch = true }) {
                        Image(systemName: "person.2")
                            .foregroundColor(.stackGreen)
                    }
                }
            }
            .task {
                await viewModel.loadGames(
                    lat: locationManager.latitude,
                    lng: locationManager.longitude
                )
            }
            .refreshable {
                await viewModel.loadGames(
                    lat: locationManager.latitude,
                    lng: locationManager.longitude
                )
            }
            .sheet(isPresented: $showingPlayerSearch) {
                PlayerSearchView()
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
