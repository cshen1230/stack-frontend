import SwiftUI

struct TabBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(DeepLinkRouter.self) private var deepLinkRouter
    var body: some View {
        @Bindable var appStateBindable = appState
        TabView(selection: $appStateBindable.selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: appState.selectedTab == 0 ? "house.fill" : "house")
                    Text("Home")
                }
                .tag(0)

            ScheduleTab(selectedTab: $appStateBindable.selectedTab)
                .tabItem {
                    Image(systemName: appState.selectedTab == 1 ? "calendar" : "calendar")
                    Text("Schedule")
                }
                .tag(1)

            ProfileView()
                .tabItem {
                    Image(systemName: appState.selectedTab == 2 ? "person.fill" : "person")
                    Text("Profile")
                }
                .badge(appState.pendingFriendRequestCount)
                .tag(2)
        }
        .tint(.stackGreen)
        .onChange(of: deepLinkRouter.pendingGameId) {
            if deepLinkRouter.pendingGameId != nil {
                appState.selectedTab = 0
            }
        }
        .onChange(of: appState.selectedTab) {
            if appState.selectedTab == 2 {
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
