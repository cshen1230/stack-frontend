import Foundation
import SwiftUI

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

    var accentColor: Color {
        switch self {
        case .singles: return Color(red: 0.6, green: 0.2, blue: 0.8)    // Purple
        case .doubles: return Color(red: 0.9, green: 0.2, blue: 0.2)    // Red
        case .mixedDoubles: return Color(red: 0.2, green: 0.3, blue: 0.8) // Blue
        case .drill: return Color(red: 0.9, green: 0.5, blue: 0.1)      // Orange
        }
    }
}

enum SessionType: String, Codable, Sendable, CaseIterable, Hashable {
    case casual = "casual"
    case roundRobin = "round_robin"

    var displayName: String {
        switch self {
        case .casual: return "Casual"
        case .roundRobin: return "Round Robin"
        }
    }
}

enum RoundRobinStatus: String, Codable, Sendable {
    case waiting = "waiting"
    case inProgress = "in_progress"
    case completed = "completed"
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

enum FriendshipStatus: String, Codable, Sendable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
}

enum GroupChatRole: String, Codable, Sendable {
    case admin = "admin"
    case member = "member"
}

enum GroupChatMessageType: String, Codable, Sendable {
    case text = "text"
    case sessionShare = "session_share"
    case system = "system"
}

enum CommunityVisibility: String, Codable, Sendable, CaseIterable {
    case `public` = "public"
    case inviteOnly = "invite_only"
    case `private` = "private"

    var displayName: String {
        switch self {
        case .public: return "Public"
        case .inviteOnly: return "Invite Only"
        case .private: return "Private"
        }
    }

    var description: String {
        switch self {
        case .public: return "Anyone can find and join"
        case .inviteOnly: return "Findable, but invite required"
        case .private: return "Hidden, invite required"
        }
    }

    var iconName: String {
        switch self {
        case .public: return "globe"
        case .inviteOnly: return "lock.open"
        case .private: return "lock"
        }
    }
}
