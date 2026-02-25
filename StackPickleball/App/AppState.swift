import SwiftUI
import Supabase

@Observable
class AppState {
    var isAuthenticated = false
    var needsOnboarding = false
    var currentUser: User?
    var isLoading = true
    var selectedTab: Int = 0

    private var authTask: Task<Void, Never>?

    func listenToAuthChanges() {
        guard authTask == nil else { return }
        authTask = Task {
            for await (event, session) in supabase.auth.authStateChanges {
                switch event {
                case .initialSession, .signedIn, .tokenRefreshed:
                    if let userId = session?.user.id {
                        isAuthenticated = true
                        await loadProfile(userId: userId)
                    } else {
                        isAuthenticated = false
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
