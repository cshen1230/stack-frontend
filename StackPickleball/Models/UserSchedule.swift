import Foundation

struct UserSchedule: Identifiable, Codable, Sendable {
    let id: UUID
    let userId: UUID
    var dayOfWeek: Int          // 0=Sunday, 6=Saturday
    var startTime: String       // "18:00"
    var endTime: String         // "20:00"
    var preferredFormat: GameFormat?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case dayOfWeek = "day_of_week"
        case startTime = "start_time"
        case endTime = "end_time"
        case preferredFormat = "preferred_format"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
