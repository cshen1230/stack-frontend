import Foundation

struct AvailablePlayer: Identifiable, Codable, Sendable {
    let id: UUID
    let userId: UUID
    var status: AvailabilityStatus
    var availableUntil: Date
    var preferredFormat: GameFormat?
    let createdAt: Date

    // Joined user fields
    var username: String?
    var firstName: String?
    var lastName: String?
    var duprRating: Double?
    var avatarUrl: String?

    var displayName: String {
        if let first = firstName, let last = lastName {
            return "\(first) \(last)"
        }
        return username ?? "Unknown"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case status
        case availableUntil = "available_until"
        case preferredFormat = "preferred_format"
        case createdAt = "created_at"
        case username
        case firstName = "first_name"
        case lastName = "last_name"
        case duprRating = "dupr_rating"
        case avatarUrl = "avatar_url"
    }
}
