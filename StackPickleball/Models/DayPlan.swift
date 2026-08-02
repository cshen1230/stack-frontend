import Foundation

/// Anything drawn on the timeline that has to share horizontal space with whatever it overlaps.
/// Both availability bands and booked sessions need the same treatment, and doing it twice is
/// how they end up disagreeing about what "overlapping" means.
protocol TimelinePlaceable {
    var startMinutes: Double { get }
    var endMinutes: Double { get }
    var column: Int { get set }
    var columnCount: Int { get set }
}

/// Time math for the day planner: mapping between a point on the timeline and a time of day,
/// and laying overlapping availability bands out side by side.
enum DayPlan {
    /// The window the planner draws. Earlier and later than anyone sensibly plays.
    static let firstHour = 6
    static let lastHour = 23

    static var hourCount: Int { lastHour - firstHour }

    /// Selections and drags snap to this, so you can't end up with a 5:37 start.
    static let snapMinutes = 30

    /// How long a booked session is drawn as.
    ///
    /// `games` stores only `game_datetime` — the drag that created a session contributes its
    /// start and the end is thrown away. So a block on the timeline is drawn at an assumed
    /// length rather than a known one. Ninety minutes is roughly a real session, and drawing
    /// something is much better than leaving an hour you're busy looking free; but until the
    /// end time is stored, the bottom edge of a session block is a guess and shouldn't be
    /// treated as more than that.
    static let assumedSessionMinutes: Double = 90

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

    /// Greedy lane assignment: reuse the first lane whose last item has already ended, then
    /// give each item a share of the width based only on what it actually overlaps — so one
    /// clash at 9am doesn't squeeze the 3pm session that has the row to itself.
    static func assignLanes<T: TimelinePlaceable>(_ items: [T]) -> [T] {
        var placed = items.sorted { $0.startMinutes < $1.startMinutes }

        var laneEnds: [Double] = []
        for index in placed.indices {
            if let lane = laneEnds.firstIndex(where: { $0 <= placed[index].startMinutes }) {
                laneEnds[lane] = placed[index].endMinutes
                placed[index].column = lane
            } else {
                laneEnds.append(placed[index].endMinutes)
                placed[index].column = laneEnds.count - 1
            }
        }

        for index in placed.indices {
            let overlapping = placed.filter {
                $0.startMinutes < placed[index].endMinutes && $0.endMinutes > placed[index].startMinutes
            }
            placed[index].columnCount = max(1, (overlapping.map(\.column).max() ?? 0) + 1)
        }

        return placed
    }

    /// One friend's availability, placed on the timeline.
    struct Band: Identifiable, TimelinePlaceable {
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

        let placed: [Band] = slots.compactMap { slot in
            let from = max(slot.start, start)
            let to = min(slot.end, end)
            guard to > from else { return nil }
            return Band(
                slot: slot,
                startMinutes: from.timeIntervalSince(start) / 60,
                endMinutes: to.timeIntervalSince(start) / 60
            )
        }

        return assignLanes(placed)
    }

    /// A session already on the books, placed on the timeline.
    struct SessionBlock: Identifiable, TimelinePlaceable {
        let game: Game
        let startMinutes: Double
        let endMinutes: Double
        var column: Int = 0
        var columnCount: Int = 1

        var id: UUID { game.id }
        var durationMinutes: Double { endMinutes - startMinutes }
    }

    /// The sessions falling on `day`, clipped to the visible window and laid out side by side
    /// where they overlap.
    ///
    /// They used to stack, on the theory that a clash should look like a clash. In practice
    /// three back-to-back sessions drew on top of each other and buried each other's titles,
    /// which doesn't communicate a conflict so much as a broken calendar. Sitting side by side
    /// still shows the overlap — the blocks visibly share an hour — and you can read all of
    /// them, which is the part that matters when you're deciding what to do about it.
    static func sessionBlocks(
        for games: [Game],
        on day: Date,
        calendar: Calendar = .current
    ) -> [SessionBlock] {
        let start = dayStart(of: day, calendar: calendar)
        let end = dayEnd(of: day, calendar: calendar)

        let placed: [SessionBlock] = games
            .filter { !$0.isCancelled && calendar.isDate($0.gameDatetime, inSameDayAs: day) }
            .compactMap { game in
                let from = max(game.gameDatetime, start)
                let to = min(
                    game.gameDatetime.addingTimeInterval(assumedSessionMinutes * 60),
                    end
                )
                guard to > from else { return nil }
                return SessionBlock(
                    game: game,
                    startMinutes: from.timeIntervalSince(start) / 60,
                    endMinutes: to.timeIntervalSince(start) / 60
                )
            }

        return assignLanes(placed)
    }

    /// Everyone free for the whole of `range` — the people worth inviting to it.
    static func slots(
        _ slots: [FriendAvailability],
        freeDuring range: ClosedRange<Date>
    ) -> [FriendAvailability] {
        slots.filter { $0.covers(range) }
    }
}
