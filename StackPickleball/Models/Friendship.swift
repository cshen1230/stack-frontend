import Foundation

struct Friendship: Identifiable, Codable, Sendable {
    let id: UUID
    let userId: UUID
    let friendId: UUID
    let status: FriendshipStatus
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case friendId = "friend_id"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Flat row returned by `get_friends` and `get_friend_requests` RPCs.
struct FriendRow: Identifiable, Codable, Sendable {
    let friendshipId: UUID
    let friendUserId: UUID
    let username: String
    let firstName: String
    let lastName: String
    let duprRating: Double?
    let avatarUrl: String?
    let status: FriendshipStatus
    let createdAt: Date

    var id: UUID { friendshipId }

    var displayName: String {
        "\(firstName) \(lastName)"
    }

    enum CodingKeys: String, CodingKey {
        case friendshipId = "friendship_id"
        case friendUserId = "friend_user_id"
        case username
        case firstName = "first_name"
        case lastName = "last_name"
        case duprRating = "dupr_rating"
        case avatarUrl = "avatar_url"
        case status
        case createdAt = "created_at"
    }
}
