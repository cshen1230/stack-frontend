import Foundation

struct GameParticipant: Identifiable, Codable, Sendable {
    let id: UUID
    let gameId: UUID
    let userId: UUID
    var rsvpStatus: RSVPStatus
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case gameId = "game_id"
        case userId = "user_id"
        case rsvpStatus = "rsvp_status"
        case createdAt = "created_at"
    }
}

/// A game participant row joined with the user profile via Supabase's nested select.
struct ParticipantWithProfile: Identifiable, Codable, Sendable {
    let id: UUID
    let gameId: UUID
    let userId: UUID
    var rsvpStatus: RSVPStatus
    let createdAt: Date
    let users: EmbeddedUser

    struct EmbeddedUser: Codable, Sendable {
        let username: String
        let firstName: String
        let lastName: String
        let duprRating: Double?

        enum CodingKeys: String, CodingKey {
            case username
            case firstName = "first_name"
            case lastName = "last_name"
            case duprRating = "dupr_rating"
        }
    }

    var displayName: String {
        "\(users.firstName) \(users.lastName)"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case gameId = "game_id"
        case userId = "user_id"
        case rsvpStatus = "rsvp_status"
        case createdAt = "created_at"
        case users
    }
}
