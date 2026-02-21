import SwiftUI

@Observable
class FriendsViewModel {
    var friends: [FriendRow] = []
    var friendRequests: [FriendRow] = []
    var searchResults: [User] = []
    var searchText = ""
    var isLoading = false
    var errorMessage: String?

    /// IDs of users we've optimistically sent a request to (disables the Add button)
    var pendingSentIds: Set<UUID> = []

    private var currentUserId: UUID?

    func load() async {
        guard let userId = await AuthService.currentUserId() else { return }
        currentUserId = userId
        isLoading = true
        do {
            async let f = FriendService.getFriends(userId: userId)
            async let r = FriendService.getFriendRequests(userId: userId)
            friends = try await f
            friendRequests = try await r
        } catch where error.isCancellation {
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func search() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            searchResults = []
            return
        }
        do {
            let results = try await PlayerService.searchPlayers(query: query)
            let friendIds = Set(friends.map(\.friendUserId))
            let requestIds = Set(friendRequests.map(\.friendUserId))
            searchResults = results.filter { user in
                user.id != currentUserId
                    && !friendIds.contains(user.id)
                    && !requestIds.contains(user.id)
                    && !pendingSentIds.contains(user.id)
            }
        } catch where error.isCancellation {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendRequest(to userId: UUID) async {
        pendingSentIds.insert(userId)
        searchResults.removeAll { $0.id == userId }
        do {
            try await FriendService.sendFriendRequest(friendId: userId)
        } catch {
            pendingSentIds.remove(userId)
            errorMessage = error.localizedDescription
        }
    }

    func acceptRequest(_ request: FriendRow) async {
        friendRequests.removeAll { $0.id == request.id }
        do {
            try await FriendService.respondToFriendRequest(friendshipId: request.friendshipId, accept: true)
            await load()
        } catch {
            errorMessage = error.localizedDescription
            await load()
        }
    }

    func declineRequest(_ request: FriendRow) async {
        friendRequests.removeAll { $0.id == request.id }
        do {
            try await FriendService.respondToFriendRequest(friendshipId: request.friendshipId, accept: false)
        } catch {
            errorMessage = error.localizedDescription
            await load()
        }
    }

    func removeFriend(_ friend: FriendRow) async {
        friends.removeAll { $0.id == friend.id }
        do {
            try await FriendService.removeFriend(friendshipId: friend.friendshipId)
        } catch {
            errorMessage = error.localizedDescription
            await load()
        }
    }
}
