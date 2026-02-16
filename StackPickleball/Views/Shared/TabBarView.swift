import SwiftUI

struct TabBarView: View {
    @State private var selectedTab = 0
    @State private var showingCreateGame = false

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                DiscoverView()
                    .tabItem {
                        Image(systemName: selectedTab == 0 ? "magnifyingglass.circle.fill" : "magnifyingglass")
                        Text("Discover")
                    }
                    .tag(0)

                TournamentListView()
                    .tabItem {
                        Image(systemName: selectedTab == 1 ? "trophy.fill" : "trophy")
                        Text("Tournaments")
                    }
                    .tag(1)

                ProfileView()
                    .tabItem {
                        Image(systemName: selectedTab == 2 ? "person.fill" : "person")
                        Text("Profile")
                    }
                    .tag(2)
            }
            .accentColor(.stackGreen)

            // Floating action button on Discover tab
            if selectedTab == 0 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        CreateGameButton {
                            showingCreateGame = true
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 90)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateGame) {
            CreateGameView()
        }
    }
}

#Preview {
    TabBarView()
        .environment(AppState())
        .environmentObject(LocationManager.shared)
}
