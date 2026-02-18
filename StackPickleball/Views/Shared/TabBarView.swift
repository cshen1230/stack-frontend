import SwiftUI

struct TabBarView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DiscoverView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "magnifyingglass.circle.fill" : "magnifyingglass")
                    Text("Discover")
                }
                .tag(0)

            MySessionsView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right")
                    Text("Sessions")
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
    }
}

#Preview {
    TabBarView()
        .environment(AppState())
        .environmentObject(LocationManager.shared)
}
