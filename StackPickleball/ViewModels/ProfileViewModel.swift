import SwiftUI

@Observable
class ProfileViewModel {
    var user: User?
    var pastGames: [Game] = []
    var friendCount: Int = 0
    var isLoading = false
    var errorMessage: String?

    func loadProfile() async {
        isLoading = true
        errorMessage = nil
        do {
            guard let userId = await AuthService.currentUserId() else { return }
            async let profile = ProfileService.getProfile(userId: userId)
            async let games = GameService.userPastGames(userId: userId)
            async let friends = FriendService.getFriends(userId: userId)
            user = try await profile
            pastGames = try await games
            friendCount = (try? await friends.count) ?? 0
        } catch where error.isCancellation {
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func updateProfile(
        firstName: String?,
        lastName: String?,
        middleName: String?,
        username: String?,
        duprRating: Double?,
        avatarUrl: String?
    ) async {
        isLoading = true
        errorMessage = nil
        do {
            try await ProfileService.updateProfile(
                firstName: firstName,
                lastName: lastName,
                middleName: middleName,
                username: username,
                duprRating: duprRating,
                avatarUrl: avatarUrl
            )
            await loadProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    var gamesByDate: [DateComponents: [Game]] {
        Dictionary(grouping: pastGames) { game in
            Calendar.current.dateComponents([.year, .month, .day], from: game.gameDatetime)
        }
    }

    func signOut() async {
        do {
            try await AuthService.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
