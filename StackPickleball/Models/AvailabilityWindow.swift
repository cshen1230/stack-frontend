import Foundation

/// A "ready to play" window — someone is available between `availableFrom` and `availableUntil`.
///
/// `available_from` is nullable in the schema; a missing value means the window is already open.
protocol AvailabilityWindow {
    var availableFrom: Date? { get }
    var availableUntil: Date { get }
}

extension AvailabilityWindow {
    var windowStart: Date { availableFrom ?? .distantPast }

    /// Ready *right now*, as opposed to ready later on. This is the distinction the UI was
    /// missing: a window that opens in an hour is real availability, it just isn't "now".
    func isActive(at now: Date = Date()) -> Bool {
        windowStart <= now && availableUntil > now
    }

    /// Ready, but the window hasn't opened yet.
    func isUpcoming(at now: Date = Date()) -> Bool {
        windowStart > now && availableUntil > now
    }

    /// True when the window still has time left today — it opens before midnight tonight and
    /// hasn't already run out. Windows starting tomorrow or later are somebody's schedule,
    /// not who's around today.
    func fallsOnToday(_ now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard availableUntil > now else { return false }
        guard let midnight = calendar.dateInterval(of: .day, for: now)?.end else { return true }
        return windowStart < midnight
    }

    /// When the window opens, from the reader's point of view: "Now" or "1:45 PM".
    func startLabel(at now: Date = Date()) -> String {
        guard let from = availableFrom, from > now else { return "Now" }
        return from.formatted(date: .omitted, time: .shortened)
    }

    /// When the window closes: "3:45 PM".
    var endLabel: String {
        availableUntil.formatted(date: .omitted, time: .shortened)
    }

    /// The whole window: "Now – 3:45 PM" or "1:45 PM – 3:45 PM".
    func windowLabel(at now: Date = Date()) -> String {
        "\(startLabel(at: now)) – \(endLabel)"
    }
}

extension ReadyFriend: AvailabilityWindow {}

extension AvailablePlayer: AvailabilityWindow {}
