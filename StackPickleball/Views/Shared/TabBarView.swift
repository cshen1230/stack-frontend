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
                    Image(systemName: selectedTab == 1 ? "calendar.badge.clock" : "calendar.badge.clock")
                    Text("Sessions")
                }
                .tag(1)

            GroupChatsListView(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "person.3.fill" : "person.3")
                    Text("Communities")
                }
                .tag(2)

            NavigationStack {
                FriendsView()
            }
            .tabItem {
                Image(systemName: selectedTab == 3 ? "person.2.fill" : "person.2")
                Text("Friends")
            }
            .badge(appState.pendingFriendRequestCount)
            .tag(3)

            ProfileView()
                .tabItem {
                    Image(systemName: selectedTab == 4 ? "person.fill" : "person")
                    Text("Profile")
                }
                .tag(4)
        }
        .accentColor(.stackGreen)
        .onChange(of: deepLinkRouter.pendingGameId) {
            if deepLinkRouter.pendingGameId != nil {
                selectedTab = 0
            }
        }
        .onChange(of: deepLinkRouter.pendingGroupChatId) {
            if let chatId = deepLinkRouter.pendingGroupChatId {
                appState.pendingGroupChatId = chatId
                deepLinkRouter.pendingGroupChatId = nil
                selectedTab = 2
            }
        }
        .onChange(of: appState.pendingGroupChatId) {
            if appState.pendingGroupChatId != nil {
                selectedTab = 2
            }
        }
        .onChange(of: selectedTab) {
            if selectedTab == 3 {
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
