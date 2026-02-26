import Foundation
import CoreLocation

struct Game: Identifiable, Codable, Sendable, Hashable {
    static func == (lhs: Game, rhs: Game) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    let id: UUID
    let creatorId: UUID
    var gameDatetime: Date
    var locationName: String?
    var skillLevelMin: Double?
    var skillLevelMax: Double?
    var spotsAvailable: Int
    var spotsFilled: Int
    var gameFormat: GameFormat
    var sessionName: String?
    var sessionType: SessionType?
    var numRounds: Int?
    var roundRobinStatus: RoundRobinStatus?
    var description: String?
    var isCancelled: Bool
    var friendsOnly: Bool
    let createdAt: Date
    var updatedAt: Date

    // Coordinates (extracted from PostGIS geography column)
    var latitude: Double?
    var longitude: Double?

    // Joined creator fields (populated via select queries)
    var creatorUsername: String?
    var creatorFirstName: String?
    var creatorLastName: String?

    var spotsRemaining: Int {
        spotsAvailable - spotsFilled
    }

    var creatorDisplayName: String {
        if let first = creatorFirstName, let last = creatorLastName {
            return "\(first) \(last)"
        }
        return creatorUsername ?? "Unknown"
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lng = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator_id"
        case gameDatetime = "game_datetime"
        case locationName = "location_name"
        case skillLevelMin = "skill_level_min"
        case skillLevelMax = "skill_level_max"
        case spotsAvailable = "spots_available"
        case spotsFilled = "spots_filled"
        case gameFormat = "game_format"
        case sessionName = "session_name"
        case sessionType = "session_type"
        case numRounds = "num_rounds"
        case roundRobinStatus = "round_robin_status"
        case description
        case isCancelled = "is_cancelled"
        case friendsOnly = "friends_only"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case latitude
        case longitude
        case creatorUsername = "creator_username"
        case creatorFirstName = "creator_first_name"
        case creatorLastName = "creator_last_name"
    }
}
