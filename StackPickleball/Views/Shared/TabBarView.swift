import SwiftUI

struct TabBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(DeepLinkRouter.self) private var deepLinkRouter
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DiscoverView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "magnifyingglass.circle.fill" : "magnifyingglass")
                    Text("Discover")
                }
                .tag(0)

            MySessionsView(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right")
                    Text("Sessions")
                }
                .tag(1)

            NavigationStack {
                FriendsView()
            }
            .tabItem {
                Image(systemName: selectedTab == 2 ? "person.2.fill" : "person.2")
                Text("Friends")
            }
            .badge(appState.pendingFriendRequestCount)
            .tag(2)

            ProfileView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "person.fill" : "person")
                    Text("Profile")
                }
                .tag(3)
        }
        .accentColor(.stackGreen)
        .onChange(of: deepLinkRouter.pendingGameId) {
            if deepLinkRouter.pendingGameId != nil {
                selectedTab = 0
            }
        }
        .onChange(of: selectedTab) {
            if selectedTab == 2 {
                Task { await appState.loadFriendRequestCount() }
            }
        }
    }
}

#Preview {
    TabBarView()
        .environment(AppState())
        .environment(DeepLinkRouter())
        .environmentObject(LocationManager.shared)
}
