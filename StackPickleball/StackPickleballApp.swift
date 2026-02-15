import SwiftUI

@main
struct StackPickleballApp: App {
    @State private var appState = AppState()
    @State private var locationManager = LocationManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environmentObject(locationManager)
                .onAppear {
                    appState.listenToAuthChanges()
                    locationManager.requestPermission()
                }
        }
    }
}
