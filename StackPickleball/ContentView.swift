import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.isLoading {
                // Boot doesn't know yet whether it lands on login or the tabs, so there's no
                // shape to skeleton — a quiet branded splash beats a spinner.
                Image("StackLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120)
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
        // Set once here so every button in the app gives under a finger; call sites that
        // pick .plain (cards, rows) opt out and handle their own feedback.
        .buttonStyle(.pressable)
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .environmentObject(LocationManager.shared)
}
