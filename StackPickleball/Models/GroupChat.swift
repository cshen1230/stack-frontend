import Foundation

struct GroupChat: Identifiable, Codable, Sendable, Hashable {
    static func == (lhs: GroupChat, rhs: GroupChat) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id: UUID
    let name: String
    let createdBy: UUID
    var gameId: UUID?
    var avatarUrl: String?
    let createdAt: Date
    var updatedAt: Date

    // Populated by RPC
    var memberCount: Int?
    var lastMessageContent: String?
    var lastMessageSenderFirstName: String?
    var lastMessageAt: Date?
    var memberAvatarUrls: [String]?

    var lastMessagePreview: String? {
        guard let content = lastMessageContent else { return nil }
        if let sender = lastMessageSenderFirstName {
            return "\(sender): \(content)"
        }
        return content
    }

    enum CodingKeys: String, CodingKey {
        case id, name
        case createdBy = "created_by"
        case gameId = "game_id"
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case memberCount = "member_count"
        case lastMessageContent = "last_message_content"
        case lastMessageSenderFirstName = "last_message_sender_first_name"
        case lastMessageAt = "last_message_at"
        case memberAvatarUrls = "member_avatar_urls"
    }
}
