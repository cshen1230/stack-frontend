import Foundation

/// Whether a session's headcount actually works.
///
/// `spots_filled / spots_available` counts seats, which says nothing about whether the number
/// is playable: eight is two clean courts, nine leaves somebody without a partner, ten sits
/// two out as a pair and rotates fine. The count people care about isn't "how full" but
/// "does this work, and if not, how many more".
struct PlayerBalance {
    let playing: Int
    let format: GameFormat

    private var perCourt: Int { format.playersPerCourt }

    /// Somebody has no partner. The state worth nudging about.
    var isOdd: Bool { playing % 2 != 0 }

    /// Courts that can run simultaneously, and whoever is left over.
    var fullCourts: Int { playing / perCourt }
    var rotating: Int { playing % perCourt }

    /// Players needed to reach the next full court — everyone on at once.
    var toFullCourt: Int { rotating == 0 ? 0 : perCourt - rotating }

    /// Not enough to start at all.
    var isShort: Bool { playing < perCourt }

    /// How many more the session should actively be looking for. Odd counts want exactly one;
    /// a short session wants a full court. An even count that rotates is fine as it is.
    var wanted: Int {
        if isShort { return perCourt - playing }
        return isOdd ? 1 : 0
    }

    /// One line for a card. Leads with the problem when there is one.
    var summary: String {
        if isShort {
            let short = perCourt - playing
            return "\(playing) in · needs \(short) more to play"
        }
        if isOdd {
            return "\(playing) in · 1 more to even up"
        }
        if rotating == 0 {
            return "\(playing) in · \(fullCourts) court\(fullCourts == 1 ? "" : "s")"
        }
        return "\(playing) in · \(rotating) rotating"
    }

    /// Short form for tight spaces.
    var shortSummary: String {
        if isShort { return "needs \(perCourt - playing)" }
        if isOdd { return "needs 1" }
        return "\(playing) in"
    }
}

extension Game {
    var balance: PlayerBalance {
        PlayerBalance(playing: spotsFilled, format: gameFormat)
    }
}
