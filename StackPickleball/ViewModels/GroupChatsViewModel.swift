import SwiftUI

@Observable
class GroupChatsViewModel {
    var groupChats: [GroupChat] = []
    var isLoading = false
    var errorMessage: String?
    var discoverableResults: [GroupChat] = []
    var isSearching = false

    private var currentUserId: UUID?

    func load() async {
        guard let userId = await AuthService.currentUserId() else { return }
        currentUserId = userId
        isLoading = true
        do {
            groupChats = try await GroupChatService.myGroupChats(userId: userId)
        } catch where error.isCancellation {
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func leaveGroupChat(_ groupChat: GroupChat) async {
        groupChats.removeAll { $0.id == groupChat.id }
        do {
            try await GroupChatService.leaveGroupChat(groupChatId: groupChat.id)
        } catch {
            errorMessage = error.localizedDescription
            await load()
        }
    }

    func deleteGroupChat(_ groupChat: GroupChat) async {
        groupChats.removeAll { $0.id == groupChat.id }
        do {
            try await GroupChatService.deleteGroupChat(groupChatId: groupChat.id)
        } catch {
            errorMessage = error.localizedDescription
            await load()
        }
    }

    func searchDiscoverable(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            discoverableResults = []
            return
        }
        isSearching = true
        do {
            discoverableResults = try await GroupChatService.searchDiscoverableCommunities(query: trimmed)
        } catch where error.isCancellation {
        } catch {
            errorMessage = error.localizedDescription
        }
        isSearching = false
    }

    func joinCommunity(_ groupChat: GroupChat) async {
        do {
            try await GroupChatService.joinCommunity(groupChatId: groupChat.id)
            discoverableResults.removeAll { $0.id == groupChat.id }
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
