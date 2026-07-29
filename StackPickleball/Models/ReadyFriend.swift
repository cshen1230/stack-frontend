import Foundation

struct ReadyFriend: Identifiable, Codable, Sendable, Hashable {
    let userId: UUID
    var username: String?
    var firstName: String?
    var lastName: String?
    var duprRating: Double?
    var duprVerified: Bool?
    var avatarUrl: String?
    var availableFrom: Date?
    var availableUntil: Date
    var preferredFormat: GameFormat?
    var note: String?

    var id: UUID { userId }

    var isDuprConnected: Bool { duprVerified == true }

    var displayName: String {
        if let first = firstName, let last = lastName {
            return "\(first) \(last)"
        }
        return username ?? "Unknown"
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case firstName = "first_name"
        case lastName = "last_name"
        case duprRating = "dupr_rating"
        case duprVerified = "dupr_verified"
        case avatarUrl = "avatar_url"
        case availableFrom = "available_from"
        case availableUntil = "available_until"
        case preferredFormat = "preferred_format"
        case note
    }
}
