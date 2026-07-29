import Foundation

struct FriendScheduleRow: Identifiable, Codable, Sendable {
    let userId: UUID
    var username: String?
    var firstName: String?
    var lastName: String?
    var duprRating: Double?
    var duprVerified: Bool?
    var avatarUrl: String?
    var startTime: String       // "18:00"
    var endTime: String         // "20:00"
    var preferredFormat: GameFormat?

    var id: String { "\(userId)-\(startTime)" }

    var isDuprConnected: Bool { duprVerified == true }

    var displayName: String {
        if let first = firstName, let last = lastName {
            return "\(first) \(last)"
        }
        return username ?? "Unknown"
    }

    var formattedTimeRange: String {
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "h:mm a"

        // PostgreSQL TIME comes as "HH:mm:ss"; also handle "HH:mm"
        let formats = ["HH:mm:ss", "HH:mm"]
        func parseTime(_ str: String) -> Date? {
            for fmt in formats {
                let f = DateFormatter()
                f.dateFormat = fmt
                if let d = f.date(from: str) { return d }
            }
            return nil
        }

        guard let start = parseTime(startTime),
              let end = parseTime(endTime) else {
            return "\(startTime) - \(endTime)"
        }
        return "\(displayFormatter.string(from: start)) - \(displayFormatter.string(from: end))"
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case firstName = "first_name"
        case lastName = "last_name"
        case duprRating = "dupr_rating"
        case duprVerified = "dupr_verified"
        case avatarUrl = "avatar_url"
        case startTime = "start_time"
        case endTime = "end_time"
        case preferredFormat = "preferred_format"
    }
}
