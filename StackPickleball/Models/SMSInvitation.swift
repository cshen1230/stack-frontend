import Foundation

struct SMSInvitation: Identifiable, Codable, Sendable {
    let id: UUID
    let gameId: UUID
    let invitedBy: UUID
    let inviteeName: String
    let phoneNumber: String
    var rsvpStatus: SMSRSVPStatus
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case gameId = "game_id"
        case invitedBy = "invited_by"
        case inviteeName = "invitee_name"
        case phoneNumber = "phone_number"
        case rsvpStatus = "rsvp_status"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum SMSRSVPStatus: String, Codable, Sendable {
    case pending
    case accepted
    case declined
    case cancelled
}

/// Transient entry used in the session-draft form before the game exists.
struct SMSInviteEntry: Identifiable {
    let id = UUID()
    var name: String = ""
    var phoneNumber: String = ""

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && phoneNumber.filter(\.isNumber).count >= 10
    }
}
