import Foundation

struct Post: Identifiable, Codable, Sendable {
    let id: UUID
    let userId: UUID
    var postType: PostType
    var caption: String?
    var mediaUrl: String
    var gameId: UUID?
    var tournamentId: UUID?
    var locationName: String?
    let createdAt: Date

    // Nested user object from joined query
    var users: PostUser?

    var posterDisplayName: String {
        if let user = users {
            return "\(user.firstName) \(user.lastName)"
        }
        return "Unknown"
    }

    var posterUsername: String? { users?.username }
    var posterAvatarUrl: String? { users?.avatarUrl }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case postType = "post_type"
        case caption
        case mediaUrl = "media_url"
        case gameId = "game_id"
        case tournamentId = "tournament_id"
        case locationName = "location_name"
        case createdAt = "created_at"
        case users
    }
}

struct PostUser: Codable, Sendable {
    let username: String
    let firstName: String
    let lastName: String
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case username
        case firstName = "first_name"
        case lastName = "last_name"
        case avatarUrl = "avatar_url"
    }
}
