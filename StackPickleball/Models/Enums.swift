import Foundation

enum GameFormat: String, Codable, Sendable, CaseIterable {
    case singles = "singles"
    case doubles = "doubles"
    case mixedDoubles = "mixed_doubles"
    case drill = "drill"

    var displayName: String {
        switch self {
        case .singles: return "Singles"
        case .doubles: return "Doubles"
        case .mixedDoubles: return "Mixed Doubles"
        case .drill: return "Drill"
        }
    }
}

enum PostType: String, Codable, Sendable {
    case sessionPhoto = "session_photo"
    case sessionClip = "session_clip"
}

enum AvailabilityStatus: String, Codable, Sendable {
    case available = "available"
    case busy = "busy"
}

enum RSVPStatus: String, Codable, Sendable {
    case confirmed = "confirmed"
    case waitlisted = "waitlisted"
    case cancelled = "cancelled"
}
