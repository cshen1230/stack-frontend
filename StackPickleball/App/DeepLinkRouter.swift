import Foundation

@Observable
class DeepLinkRouter {
    var pendingGameId: UUID?
    var pendingGroupChatId: UUID?

    func handle(_ url: URL) {
        guard url.scheme == "stackpickleball" else { return }

        switch url.host {
        case "session":
            // stackpickleball://session/<uuid>
            if let uuidString = url.pathComponents.dropFirst().first,
               let gameId = UUID(uuidString: uuidString) {
                pendingGameId = gameId
            }
        case "groupchat":
            // stackpickleball://groupchat/<uuid>
            if let uuidString = url.pathComponents.dropFirst().first,
               let chatId = UUID(uuidString: uuidString) {
                pendingGroupChatId = chatId
            }
        default:
            break
        }
    }
}
