import Foundation

struct User: Identifiable, Codable, Sendable {
    let id: UUID
    var username: String
    var firstName: String
    var middleName: String?
    var lastName: String
    var duprId: String?
    var duprRating: Double?
    var duprVerified: Bool?
    var duprSinglesRating: Double?
    var duprDoublesRating: Double?
    var avatarUrl: String?
    let createdAt: Date
    var updatedAt: Date

    var isDuprConnected: Bool { duprVerified == true }

    var displayName: String {
        if let middle = middleName, !middle.isEmpty {
            return "\(firstName) \(middle) \(lastName)"
        }
        return "\(firstName) \(lastName)"
    }

    enum CodingKeys: String, CodingKey {
        case id, username
        case firstName = "first_name"
        case middleName = "middle_name"
        case lastName = "last_name"
        case duprId = "dupr_id"
        case duprRating = "dupr_rating"
        case duprVerified = "dupr_verified"
        case duprSinglesRating = "dupr_singles_rating"
        case duprDoublesRating = "dupr_doubles_rating"
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
