import Foundation

struct AvailabilitySlot: Identifiable, Codable, Sendable {
    let id: UUID
    var dayOfWeek: Int // 1 = Monday, 7 = Sunday
    var startTime: Date // Time component only
    var endTime: Date // Time component only

    init(
        id: UUID = UUID(),
        dayOfWeek: Int,
        startTime: Date,
        endTime: Date
    ) {
        self.id = id
        self.dayOfWeek = dayOfWeek
        self.startTime = startTime
        self.endTime = endTime
    }

    // Helper to display as string, e.g., "Mon 6:00 PM-8:00 PM"
    var displayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let start = formatter.string(from: startTime)
        let end = formatter.string(from: endTime)
        let dayName = Calendar.current.shortWeekdaySymbols[dayOfWeek - 1]
        return "\(dayName) \(start)-\(end)"
    }
}
