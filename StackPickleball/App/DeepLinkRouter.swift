import Foundation

@Observable
class DeepLinkRouter {
    var pendingGameId: UUID?
    var pendingGroupChatId: UUID?
    var pendingDUPRAuthCode: String?

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
        case "dupr":
            // stackpickleball://dupr/callback?code=...
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                pendingDUPRAuthCode = code
            }
        default:
            break
        }
    }
}
