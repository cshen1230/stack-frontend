import SwiftUI

struct TabBarView: View {
    @State private var selectedTab = 0
    @State private var showingCreateGame = false

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                FeedView()
                    .tabItem {
                        Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                        Text("Feed")
                    }
                    .tag(0)

                DiscoverView()
                    .tabItem {
                        Image(systemName: selectedTab == 1 ? "magnifyingglass.circle.fill" : "magnifyingglass")
                        Text("Discover")
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

            // Floating action button
            if selectedTab == 0 || selectedTab == 1 {
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
        .environmentObject(AuthViewModel())
}
