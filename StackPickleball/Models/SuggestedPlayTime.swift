import Foundation

/// A (day, hour) slot the user has played at multiple times in the past.
/// Returned by the `suggested_play_times` RPC and used to offer a quick-start
/// shortcut on the home planner.
struct SuggestedPlayTime: Decodable, Sendable {
    /// 0 = Sunday, 6 = Saturday (PostgreSQL `DOW` convention).
    let dayOfWeek: Int
    /// 0-23 in the user's local timezone.
    let hourOfDay: Int
    let playCount: Int

    enum CodingKeys: String, CodingKey {
        case dayOfWeek = "day_of_week"
        case hourOfDay = "hour_of_day"
        case playCount = "play_count"
    }

    /// "Thursday", "Monday", etc.
    var weekdayName: String {
        // Calendar weekday is 1-indexed (1 = Sunday), DOW is 0-indexed (0 = Sunday).
        let symbols = Calendar.current.weekdaySymbols
        return symbols[dayOfWeek % 7]
    }

    /// "6 PM", "10 AM", etc.
    var hourLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        var components = DateComponents()
        components.hour = hourOfDay
        guard let date = Calendar.current.date(from: components) else { return "\(hourOfDay):00" }
        return formatter.string(from: date)
    }

    /// The next future date that matches this day-of-week and hour.
    func nextOccurrence(from now: Date = Date()) -> Date {
        let calendar = Calendar.current
        // Calendar weekday: 1 = Sunday. DOW: 0 = Sunday.
        let targetWeekday = dayOfWeek + 1

        let todayWeekday = calendar.component(.weekday, from: now)
        var daysAhead = targetWeekday - todayWeekday
        if daysAhead < 0 { daysAhead += 7 }

        // If it's today but the hour has already passed, jump a week.
        if daysAhead == 0 {
            let currentHour = calendar.component(.hour, from: now)
            if currentHour >= hourOfDay { daysAhead = 7 }
        }

        let targetDay = calendar.date(byAdding: .day, value: daysAhead, to: calendar.startOfDay(for: now))!
        return calendar.date(bySettingHour: hourOfDay, minute: 0, second: 0, of: targetDay)!
    }
}
