import Foundation

/// The chunks of a day people actually think in. Availability is captured as taps on these
/// rather than exact times — "I usually play Tuesday evenings" is inherently fuzzy, and asking
/// for 6:00–8:00 pretends to a precision nobody has.
enum DayPart: String, CaseIterable, Codable, Sendable, Hashable {
    case morning
    case earlyAfternoon
    case lateAfternoon
    case night

    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .earlyAfternoon: return "Early afternoon"
        case .lateAfternoon: return "Late afternoon"
        case .night: return "Night"
        }
    }

    /// Short form for the compact grid.
    var shortName: String {
        switch self {
        case .morning: return "Morning"
        case .earlyAfternoon: return "Early PM"
        case .lateAfternoon: return "Late PM"
        case .night: return "Night"
        }
    }

    var systemImage: String {
        switch self {
        case .morning: return "sunrise"
        case .earlyAfternoon: return "sun.max"
        case .lateAfternoon: return "sun.haze"
        case .night: return "moon.stars"
        }
    }

    /// Hours the part covers, aligned to the planner's 6 AM – 11 PM window.
    var startHour: Int {
        switch self {
        case .morning: return 6
        case .earlyAfternoon: return 12
        case .lateAfternoon: return 15
        case .night: return 18
        }
    }

    var endHour: Int {
        switch self {
        case .morning: return 12
        case .earlyAfternoon: return 15
        case .lateAfternoon: return 18
        case .night: return 22
        }
    }

    /// "06:00" — the form the existing save path sends.
    var startTimeString: String { String(format: "%02d:00", startHour) }
    var endTimeString: String { String(format: "%02d:00", endHour) }

    var timeRangeLabel: String {
        "\(DayPart.hourLabel(startHour))–\(DayPart.hourLabel(endHour))"
    }

    private static func hourLabel(_ hour: Int) -> String {
        let suffix = hour < 12 ? "am" : "pm"
        var display = hour % 12
        if display == 0 { display = 12 }
        return "\(display)\(suffix)"
    }

    /// The parts a stored window covers, so a saved schedule can be shown back as taps.
    /// A window counts as covering a part when it overlaps most of it.
    static func parts(coveringHours start: Int, _ end: Int) -> Set<DayPart> {
        Set(allCases.filter { part in
            let overlap = min(end, part.endHour) - max(start, part.startHour)
            return overlap > 0 && Double(overlap) >= Double(part.endHour - part.startHour) / 2
        })
    }

    /// Collapses a set of parts into the fewest contiguous windows, so touching selections
    /// become one band on the calendar instead of two abutting ones.
    static func mergedWindows(from parts: Set<DayPart>) -> [(start: String, end: String)] {
        let ordered = allCases.filter { parts.contains($0) }
        var windows: [(start: String, end: String)] = []
        for part in ordered {
            if var last = windows.last, last.end == part.startTimeString {
                last.end = part.endTimeString
                windows[windows.count - 1] = last
            } else {
                windows.append((part.startTimeString, part.endTimeString))
            }
        }
        return windows
    }
}
