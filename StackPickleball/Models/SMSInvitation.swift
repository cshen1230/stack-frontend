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

    /// The number, but only for the person who typed it in.
    ///
    /// Everyone in the session can now read these rows — they have to, or an SMS guest counts
    /// toward the roster while being invisible on it. That makes the roster right and hands
    /// everyone a guest's phone number as a side effect, which is not what giving a number to
    /// one organiser was consent for. So the row still shows for everybody; the number itself
    /// shows only to whoever entered it.
    func displayPhoneNumber(viewerId: UUID?) -> String? {
        guard let viewerId, viewerId == invitedBy else { return nil }
        return phoneNumber
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
            && SMSInviteEntry.looksLikeAPhoneNumber(phoneNumber)
    }

    /// Mirrors `normalizePhoneNumber` in the edge function, so a number that will be refused is
    /// refused here — while the person can still see the field they typed it into, rather than
    /// after the session exists and the invite has quietly failed.
    static func looksLikeAPhoneNumber(_ raw: String) -> Bool {
        let digits = raw.filter(\.isNumber)

        // Written internationally: trust the country code, check only that the length is sane.
        if raw.trimmingCharacters(in: .whitespaces).hasPrefix("+") {
            return (8...15).contains(digits.count)
        }

        // NANP, with or without the leading 1. Area codes and exchanges both start 2-9, which
        // is what separates a real number from ten digits of something else.
        let national = digits.count == 11 && digits.hasPrefix("1")
            ? String(digits.dropFirst())
            : digits
        guard national.count == 10 else { return false }

        let chars = Array(national)
        return ("2"..."9").contains(String(chars[0])) && ("2"..."9").contains(String(chars[3]))
    }
}
