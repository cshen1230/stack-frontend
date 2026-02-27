import Foundation

struct GroupChatMessage: Identifiable, Codable, Sendable {
    let id: UUID
    let groupChatId: UUID
    let userId: UUID
    let content: String
    let messageType: GroupChatMessageType
    var sharedGameId: UUID?
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
        case groupChatId = "group_chat_id"
        case userId = "user_id"
        case content
        case messageType = "message_type"
        case sharedGameId = "shared_game_id"
        case createdAt = "created_at"
        case users
    }
}
