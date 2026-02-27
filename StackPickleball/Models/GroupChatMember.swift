import Foundation

struct GroupChatMember: Identifiable, Codable, Sendable {
    let id: UUID
    let groupChatId: UUID
    let userId: UUID
    var role: GroupChatRole
    let joinedAt: Date
    let users: MemberUser

    struct MemberUser: Codable, Sendable {
        let firstName: String
        let lastName: String
        let avatarUrl: String?
        let duprRating: Double?

        enum CodingKeys: String, CodingKey {
            case firstName = "first_name"
            case lastName = "last_name"
            case avatarUrl = "avatar_url"
            case duprRating = "dupr_rating"
        }
    }

    var displayName: String {
        "\(users.firstName) \(users.lastName)"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case groupChatId = "group_chat_id"
        case userId = "user_id"
        case role
        case joinedAt = "joined_at"
        case users
    }
}
