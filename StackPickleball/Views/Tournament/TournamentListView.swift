import SwiftUI

struct TournamentListView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @State private var viewModel = TournamentViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading && viewModel.tournaments.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.tournaments.isEmpty {
                    EmptyStateView(
                        icon: "trophy",
                        title: "No Tournaments",
                        message: "No upcoming tournaments found near you."
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.tournaments) { tournament in
                                TournamentCardView(tournament: tournament)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                }
            }
            .background(Color.white)
            .navigationTitle("Tournaments")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .task {
                await viewModel.loadTournaments(
                    lat: locationManager.latitude,
                    lng: locationManager.longitude
                )
            }
            .refreshable {
                await viewModel.loadTournaments(
                    lat: locationManager.latitude,
                    lng: locationManager.longitude
                )
            }
            .errorAlert($viewModel.errorMessage)
        }
    }
}

#Preview {
    TournamentListView()
        .environmentObject(LocationManager.shared)
}
