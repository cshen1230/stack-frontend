import SwiftUI
import Supabase

@Observable
class AppState {
    var isAuthenticated = false
    var needsOnboarding = false
    var currentUser: User?
    var isLoading = true
    var selectedTab: Int = 0
    var pendingFriendRequestCount: Int = 0
    var pendingGroupChatId: UUID?
    var unreadGroupChatCount: Int = 0

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
                        await loadFriendRequestCount()
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

    func loadFriendRequestCount() async {
        guard let userId = currentUser?.id else { return }
        do {
            let requests = try await FriendService.getFriendRequests(userId: userId)
            pendingFriendRequestCount = requests.count
        } catch {
            // silently ignore — badge is non-critical
        }
    }
}
