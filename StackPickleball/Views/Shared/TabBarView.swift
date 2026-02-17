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

            ProfileView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "person.fill" : "person")
                    Text("Profile")
                }
                .tag(1)
        }
        .accentColor(.stackGreen)
    }
}

#Preview {
    TabBarView()
        .environment(AppState())
        .environmentObject(LocationManager.shared)
}
