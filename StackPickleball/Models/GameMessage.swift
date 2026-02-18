import Foundation

struct GameMessage: Identifiable, Codable, Sendable {
    let id: UUID
    let gameId: UUID
    let userId: UUID
    let content: String
    let createdAt: Date
    let users: MessageUser

    struct MessageUser: Codable, Sendable {
        let firstName: String
        let lastName: String
        let avatarUrl: String?

        enum CodingKeys: String, CodingKey {
            case firstName = "first_name"
            case lastName = "last_name"
            case avatarUrl = "avatar_url"
        }
    }

    var senderDisplayName: String {
        "\(users.firstName) \(users.lastName)"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case gameId = "game_id"
        case userId = "user_id"
        case content
        case createdAt = "created_at"
        case users
    }
}
