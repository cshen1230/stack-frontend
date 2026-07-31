import Foundation

/// A friend's usual availability resolved onto a concrete day, which is what the calendar can
/// actually draw. `user_schedules` stores a weekday plus a time of day; this pins that to a date.
struct FriendAvailability: Identifiable, Hashable {
    let userId: UUID
    let displayName: String
    let firstName: String?
    let avatarUrl: String?
    let duprRating: Double?
    let duprVerified: Bool?
    let preferredFormat: GameFormat?
    let start: Date
    let end: Date
    /// Your own window, drawn differently so the calendar shows where you sit among friends.
    var isSelf: Bool = false

    /// One friend can have several windows on the same day, so identity includes the start.
    var id: String { "\(userId)-\(start.timeIntervalSince1970)" }

    var isDuprConnected: Bool { duprVerified == true }

    var shortName: String { firstName ?? displayName }

    var timeRangeLabel: String {
        let from = start.formatted(date: .omitted, time: .shortened)
        let to = end.formatted(date: .omitted, time: .shortened)
        return "\(from) – \(to)"
    }

    /// Covers `range` entirely — the people worth pre-selecting for a session in that slot.
    func covers(_ range: ClosedRange<Date>) -> Bool {
        start <= range.lowerBound && end >= range.upperBound
    }

    /// Resolves the weekday rows for `day` onto that date. Rows whose times don't parse are
    /// dropped rather than drawn at midnight.
    static func resolve(_ rows: [FriendScheduleRow], on day: Date, calendar: Calendar = .current) -> [FriendAvailability] {
        let midnight = calendar.startOfDay(for: day)
        return rows.compactMap { row in
            guard let start = date(from: row.startTime, on: midnight, calendar: calendar),
                  let end = date(from: row.endTime, on: midnight, calendar: calendar),
                  end > start else { return nil }
            return FriendAvailability(
                userId: row.userId,
                displayName: row.displayName,
                firstName: row.firstName,
                avatarUrl: row.avatarUrl,
                duprRating: row.duprRating,
                duprVerified: row.duprVerified,
                preferredFormat: row.preferredFormat,
                start: start,
                end: end
            )
        }
        .sorted { $0.start < $1.start }
    }

    /// Your own saved windows, resolved onto `day` the same way friends' are.
    static func resolveOwn(_ schedule: [UserSchedule], on day: Date, calendar: Calendar = .current) -> [FriendAvailability] {
        let midnight = calendar.startOfDay(for: day)
        // Stored day_of_week is 0-based from Sunday; Calendar's weekday is 1-based.
        let weekday = calendar.component(.weekday, from: day) - 1
        return schedule.compactMap { window in
            guard window.dayOfWeek == weekday,
                  let start = date(from: window.startTime, on: midnight, calendar: calendar),
                  let end = date(from: window.endTime, on: midnight, calendar: calendar),
                  end > start else { return nil }
            return FriendAvailability(
                userId: window.userId,
                displayName: "You",
                firstName: "You",
                avatarUrl: nil,
                duprRating: nil,
                duprVerified: nil,
                preferredFormat: window.preferredFormat,
                start: start,
                end: end,
                isSelf: true
            )
        }
        .sorted { $0.start < $1.start }
    }

    /// PostgreSQL TIME arrives as "HH:mm:ss"; tolerate "HH:mm" too.
    private static func date(from time: String, on midnight: Date, calendar: Calendar) -> Date? {
        let pieces = time.split(separator: ":").compactMap { Int($0) }
        guard pieces.count >= 2 else { return nil }
        return calendar.date(byAdding: .minute, value: pieces[0] * 60 + pieces[1], to: midnight)
    }
}
