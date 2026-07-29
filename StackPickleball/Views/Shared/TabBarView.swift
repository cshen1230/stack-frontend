import SwiftUI

struct TabBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(DeepLinkRouter.self) private var deepLinkRouter
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("Home")
                }
                .tag(0)

            ScheduleTab(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "calendar" : "calendar")
                    Text("Schedule")
                }
                .tag(1)

            ProfileView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "person.fill" : "person")
                    Text("Profile")
                }
                .badge(appState.pendingFriendRequestCount)
                .tag(2)
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
