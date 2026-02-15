import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.stackBackground)
            } else if !appState.isAuthenticated {
                LoginView()
            } else if appState.needsOnboarding {
                OnboardingView()
            } else {
                TabBarView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .environmentObject(LocationManager.shared)
}
