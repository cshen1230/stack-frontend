import Foundation

/// Time math for the day planner: mapping between a point on the timeline and a time of day,
/// and laying overlapping availability bands out side by side.
enum DayPlan {
    /// The window the planner draws. Earlier and later than anyone sensibly plays.
    static let firstHour = 6
    static let lastHour = 23

    static var hourCount: Int { lastHour - firstHour }

    /// Selections and drags snap to this, so you can't end up with a 5:37 start.
    static let snapMinutes = 30

    // MARK: - Point <-> time

    /// Minutes from the top of the timeline for a given date.
    static func minutesFromTop(for date: Date, on day: Date, calendar: Calendar = .current) -> Double {
        let start = dayStart(of: day, calendar: calendar)
        return date.timeIntervalSince(start) / 60
    }

    /// The date represented by a vertical offset, snapped to `snapMinutes`.
    static func date(atMinutes minutes: Double, on day: Date, calendar: Calendar = .current) -> Date {
        let snapped = (minutes / Double(snapMinutes)).rounded() * Double(snapMinutes)
        let clamped = min(max(snapped, 0), Double(hourCount * 60))
        return dayStart(of: day, calendar: calendar).addingTimeInterval(clamped * 60)
    }

    /// `firstHour` on the given day.
    static func dayStart(of day: Date, calendar: Calendar = .current) -> Date {
        let midnight = calendar.startOfDay(for: day)
        return calendar.date(byAdding: .hour, value: firstHour, to: midnight) ?? midnight
    }

    static func dayEnd(of day: Date, calendar: Calendar = .current) -> Date {
        dayStart(of: day, calendar: calendar).addingTimeInterval(TimeInterval(hourCount * 3600))
    }

    /// Hour label for the gutter: "6 AM", "12 PM", "8 PM".
    static func hourLabel(_ hour: Int) -> String {
        let normalized = hour % 24
        let suffix = normalized < 12 ? "AM" : "PM"
        var display = normalized % 12
        if display == 0 { display = 12 }
        return "\(display) \(suffix)"
    }

    // MARK: - Overlap layout

    /// One friend's availability, placed on the timeline.
    struct Band: Identifiable {
        let slot: FriendAvailability
        /// Minutes from the top of the timeline.
        let startMinutes: Double
        let endMinutes: Double
        /// Which of `columnCount` side-by-side lanes this band sits in.
        var column: Int = 0
        var columnCount: Int = 1

        var id: String { slot.id }
        var durationMinutes: Double { endMinutes - startMinutes }
    }

    /// Clips each window to the visible day and lays overlapping ones out in lanes, so two
    /// people free at the same time sit next to each other rather than on top.
    static func bands(
        for slots: [FriendAvailability],
        on day: Date,
        calendar: Calendar = .current
    ) -> [Band] {
        let start = dayStart(of: day, calendar: calendar)
        let end = dayEnd(of: day, calendar: calendar)

        var placed: [Band] = slots.compactMap { slot in
            let from = max(slot.start, start)
            let to = min(slot.end, end)
            guard to > from else { return nil }
            return Band(
                slot: slot,
                startMinutes: from.timeIntervalSince(start) / 60,
                endMinutes: to.timeIntervalSince(start) / 60
            )
        }
        .sorted { $0.startMinutes < $1.startMinutes }

        // Greedy lane assignment: reuse the first lane whose last band has already ended.
        var laneEnds: [Double] = []
        for index in placed.indices {
            let lane = laneEnds.firstIndex { $0 <= placed[index].startMinutes }
            if let lane {
                laneEnds[lane] = placed[index].endMinutes
                placed[index].column = lane
            } else {
                laneEnds.append(placed[index].endMinutes)
                placed[index].column = laneEnds.count - 1
            }
        }

        // Bands only need to share width with the ones they actually overlap.
        for index in placed.indices {
            let overlapping = placed.filter {
                $0.startMinutes < placed[index].endMinutes && $0.endMinutes > placed[index].startMinutes
            }
            placed[index].columnCount = max(1, (overlapping.map(\.column).max() ?? 0) + 1)
        }

        return placed
    }

    /// Everyone free for the whole of `range` — the people worth inviting to it.
    static func slots(
        _ slots: [FriendAvailability],
        freeDuring range: ClosedRange<Date>
    ) -> [FriendAvailability] {
        slots.filter { $0.covers(range) }
    }
}
