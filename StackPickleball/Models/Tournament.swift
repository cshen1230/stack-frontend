import Foundation

struct Tournament: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var locationName: String?
    var startDate: Date
    var endDate: Date
    var skillDivisions: [String]?
    var registrationUrl: String?
    var description: String?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case locationName = "location_name"
        case startDate = "start_date"
        case endDate = "end_date"
        case skillDivisions = "skill_divisions"
        case registrationUrl = "registration_url"
        case description
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
