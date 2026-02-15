import Foundation

struct Post: Identifiable, Codable, Sendable {
    let id: UUID
    let userId: UUID
    var userName: String
    var userImageURL: String?
    let type: PostType
    var content: String?
    var mediaURL: String?
    var gameId: UUID?
    var gameDetails: GameDetails?
    var likes: Int
    var comments: Int
    var timestamp: Date

    init(
        id: UUID = UUID(),
        userId: UUID,
        userName: String,
        userImageURL: String? = nil,
        type: PostType,
        content: String? = nil,
        mediaURL: String? = nil,
        gameId: UUID? = nil,
        gameDetails: GameDetails? = nil,
        likes: Int = 0,
        comments: Int = 0,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.userImageURL = userImageURL
        self.type = type
        self.content = content
        self.mediaURL = mediaURL
        self.gameId = gameId
        self.gameDetails = gameDetails
        self.likes = likes
        self.comments = comments
        self.timestamp = timestamp
    }
}

// Nested struct for embedded game details in posts
struct GameDetails: Codable, Sendable {
    let time: Date
    let location: String
    let skillLevel: String // e.g., "DUPR 4.0-4.5"
    let playerCount: String // e.g., "3/4 players"
}
