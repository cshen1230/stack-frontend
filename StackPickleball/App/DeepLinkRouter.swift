import Foundation

@Observable
class DeepLinkRouter {
    var pendingGameId: UUID?

    func handle(_ url: URL) {
        // Expected format: stackpickleball://session/<uuid>
        guard url.scheme == "stackpickleball",
              url.host == "session",
              let uuidString = url.pathComponents.dropFirst().first,
              let gameId = UUID(uuidString: uuidString) else {
            return
        }
        pendingGameId = gameId
    }
}
