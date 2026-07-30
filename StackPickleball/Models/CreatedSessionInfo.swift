import Foundation

/// What the confirmation toast needs after a session is created.
struct CreatedSessionInfo {
    /// Short line for the toast — the time range, since sessions no longer carry a name.
    let headline: String
    let sessionType: SessionType
    let gameFormat: GameFormat
    let spotsAvailable: Int
    let locationName: String?
}
