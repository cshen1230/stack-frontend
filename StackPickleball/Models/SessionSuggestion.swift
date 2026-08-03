import Foundation

/// A concrete slot worth proposing: a time, and who could make it.
///
/// The planner's drag is a good way to answer "when?" but it asks the question cold. Everything
/// needed to answer it is already loaded — your recurring times, your friends' recurring times,
/// what you're already committed to — so for most people the app can just say "Thursday 6pm,
/// four of your friends are free" and be right. One tap beats any gesture.
struct SessionSuggestion: Identifiable, Hashable {
    let range: ClosedRange<Date>
    /// Friends whose usual times cover the whole slot.
    let freeFriends: [String]

    var id: Date { range.lowerBound }
    var friendCount: Int { freeFriends.count }

    /// How long a proposed slot runs. Matches what the timeline draws a booked session as, so
    /// accepting a suggestion produces a block the same size as the one you were shown.
    static let slotMinutes: Double = DayPlan.assumedSessionMinutes

    /// "Today", "Tomorrow", "Sat" — plus the time.
    func title(calendar: Calendar = .current) -> String {
        let start = range.lowerBound
        let day: String
        if calendar.isDateInToday(start) {
            day = "Today"
        } else if calendar.isDateInTomorrow(start) {
            day = "Tomorrow"
        } else {
            day = start.formatted(.dateTime.weekday(.abbreviated))
        }
        return "\(day) \(start.formatted(date: .omitted, time: .shortened))"
    }

    var subtitle: String {
        switch freeFriends.count {
        case 0: return "You're free"
        case 1: return "\(freeFriends[0]) is free"
        case 2: return "\(freeFriends[0]) and \(freeFriends[1]) are free"
        default: return "\(freeFriends.count) friends free"
        }
    }

    // MARK: - Building

    /// The best slot on each of the next `dayCount` days, best first.
    ///
    /// Deliberately at most one per day: three suggestions that are all Thursday aren't three
    /// choices, they're one choice presented three times. Spreading across days is what makes
    /// the row worth reading.
    static func best(
        friendSchedules: [Int: [FriendScheduleRow]],
        mySchedule: [UserSchedule],
        busy: [Game],
        limit: Int = 3,
        dayCount: Int = 7,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [SessionSuggestion] {
        let today = calendar.startOfDay(for: now)
        // Nobody wants to be told about a game starting in ten minutes.
        let earliest = now.addingTimeInterval(60 * 60)

        var perDay: [SessionSuggestion] = []

        for offset in 0..<dayCount {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }

            let weekday = calendar.component(.weekday, from: day)
            let friends = FriendAvailability.resolve(friendSchedules[weekday] ?? [], on: day)
            let mine = FriendAvailability.resolveOwn(mySchedule, on: day)
            guard !friends.isEmpty || !mine.isEmpty else { continue }

            if let bestToday = bestSlot(
                on: day,
                friends: friends,
                mine: mine,
                busy: busy,
                notBefore: earliest,
                calendar: calendar
            ) {
                perDay.append(bestToday)
            }
        }

        return perDay
            .sorted {
                // More friends wins; a tie goes to whichever is sooner, because a slot you can
                // act on today is worth more than an equally good one next week.
                $0.friendCount == $1.friendCount
                    ? $0.range.lowerBound < $1.range.lowerBound
                    : $0.friendCount > $1.friendCount
            }
            .prefix(limit)
            .map { $0 }
    }

    /// Walks the day in half-hour steps and keeps the slot the most friends can make.
    private static func bestSlot(
        on day: Date,
        friends: [FriendAvailability],
        mine: [FriendAvailability],
        busy: [Game],
        notBefore: Date,
        calendar: Calendar
    ) -> SessionSuggestion? {
        let dayStart = DayPlan.dayStart(of: day, calendar: calendar)
        let dayEnd = DayPlan.dayEnd(of: day, calendar: calendar)
        let slot = slotMinutes * 60
        let step = Double(DayPlan.snapMinutes) * 60

        // Only the sessions on this day matter, and only as "this time is taken".
        let taken: [ClosedRange<Date>] = busy
            .filter { !$0.isCancelled && calendar.isDate($0.gameDatetime, inSameDayAs: day) }
            .map { $0.gameDatetime...$0.gameDatetime.addingTimeInterval(slot) }

        var best: SessionSuggestion?

        var start = dayStart
        while start.addingTimeInterval(slot) <= dayEnd {
            defer { start = start.addingTimeInterval(step) }

            guard start >= notBefore else { continue }
            let range = start...start.addingTimeInterval(slot)

            // Don't propose a time you've already committed to.
            if taken.contains(where: { $0.overlaps(range) }) { continue }

            // If you've said when you play, respect it — a suggestion you can't make is worse
            // than none. If you haven't, every slot is fair game rather than no slot being one.
            if !mine.isEmpty, !mine.contains(where: { $0.covers(range) }) { continue }

            let available = friends.filter { $0.covers(range) }
            let names = Array(Set(available.map(\.shortName))).sorted()
            let candidate = SessionSuggestion(range: range, freeFriends: names)

            if best == nil || candidate.friendCount > best!.friendCount {
                best = candidate
            }
        }

        // A slot nobody can make isn't a suggestion, unless it's the only thing we can offer —
        // which is the case for someone whose friends haven't shared any times yet.
        if let best, best.friendCount == 0, !friends.isEmpty { return nil }
        return best
    }

    /// Where "Start a game" lands when there's nothing to suggest: the next half hour at least
    /// an hour out, or tomorrow evening once today has run out of daylight.
    static func defaultRange(now: Date = Date(), calendar: Calendar = .current) -> ClosedRange<Date> {
        let slot = slotMinutes * 60
        let step = Double(DayPlan.snapMinutes) * 60

        let target = now.addingTimeInterval(60 * 60)
        let sinceStart = target.timeIntervalSince(DayPlan.dayStart(of: target, calendar: calendar))
        let rounded = DayPlan.dayStart(of: target, calendar: calendar)
            .addingTimeInterval((sinceStart / step).rounded(.up) * step)

        if rounded.addingTimeInterval(slot) <= DayPlan.dayEnd(of: target, calendar: calendar) {
            return rounded...rounded.addingTimeInterval(slot)
        }

        // Out of hours today — 6pm tomorrow is the answer people would have picked anyway.
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let evening = calendar.date(byAdding: .hour, value: 18, to: tomorrow) ?? tomorrow
        return evening...evening.addingTimeInterval(slot)
    }
}
