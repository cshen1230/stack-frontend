import SwiftUI
import Supabase

@Observable
class AppState {
    var isAuthenticated = false
    var needsOnboarding = false
    var currentUser: User?
    var isLoading = true
    var selectedTab: Int = 0

    func listenToAuthChanges() {
        Task {
            for await (event, session) in supabase.auth.authStateChanges {
                switch event {
                case .signedIn:
                    isAuthenticated = true
                    if let userId = session?.user.id {
                        await loadProfile(userId: userId)
                    }
                case .signedOut:
                    isAuthenticated = false
                    needsOnboarding = false
                    currentUser = nil
                default:
                    break
                }
                isLoading = false
            }
        }
    }

    func loadProfile(userId: UUID) async {
        do {
            let profile = try await ProfileService.getProfile(userId: userId)
            currentUser = profile
            needsOnboarding = (profile == nil)
        } catch {
            needsOnboarding = true
        }
    }
}
