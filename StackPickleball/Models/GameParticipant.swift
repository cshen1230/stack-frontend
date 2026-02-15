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
