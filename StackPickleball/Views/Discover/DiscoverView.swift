import SwiftUI

struct DiscoverView: View {
    @StateObject private var viewModel = DiscoverViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                FilterBarView(
                    duprMin: $viewModel.selectedDUPRMin,
                    duprMax: $viewModel.selectedDUPRMax,
                    date: $viewModel.selectedDate,
                    distance: $viewModel.selectedDistance,
                    onApply: {
                        viewModel.applyFilters()
                    }
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white)

                Divider()

                // Games list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.games) { game in
                            GameCardView(game: game) {
                                Task {
                                    await viewModel.joinGame(game)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
                .background(Color.stackBackground)
            }
            .navigationTitle("Discover Games")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        // TODO: Open search/advanced filters
                    }) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.black)
                    }
                }
            }
        }
    }
}

#Preview {
    DiscoverView()
}
