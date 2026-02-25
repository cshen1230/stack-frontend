import SwiftUI

@main
struct StackPickleballApp: App {
    @State private var appState = AppState()
    @State private var locationManager = LocationManager.shared
    @State private var deepLinkRouter = DeepLinkRouter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(deepLinkRouter)
                .environmentObject(locationManager)
                .onAppear {
                    appState.listenToAuthChanges()
                    locationManager.requestPermission()
                }
                .onOpenURL { url in
                    deepLinkRouter.handle(url)
                }
        }
    }
}
