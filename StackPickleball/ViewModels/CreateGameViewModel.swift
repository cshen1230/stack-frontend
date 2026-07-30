import SwiftUI

struct CreatedSessionInfo {
    let sessionName: String
    let sessionType: SessionType
    let gameFormat: GameFormat
    let spotsAvailable: Int
    let locationName: String?
}

@Observable
class CreateGameViewModel {
    var sessionType: SessionType = .casual
    var sessionName = ""
    var locationName = ""
    var selectedLatitude: Double?
    var selectedLongitude: Double?
    var selectedDate = CreateGameViewModel.defaultStartDate()
    var skillLevelMin: Double = 0.0
    var gameFormat: GameFormat = .doubles
    var spotsAvailable: Int = 4
    var numRounds: Int = 5
    var description = ""
    var friendsOnly = false

    var isLoading = false
    var errorMessage: String?
    var showingSuccess = false

    var isRoundRobin: Bool { sessionType == .roundRobin }

    /// The server requires `game_datetime` to be strictly in the future, so defaulting the
    /// picker to `Date()` fails for everyone — filling in the form takes longer than zero
    /// seconds. Start half an hour out, rounded up to the next quarter hour.
    static func defaultStartDate(from now: Date = Date()) -> Date {
        let earliest = now.addingTimeInterval(30 * 60)
        let quarterHour: TimeInterval = 15 * 60
        return Date(
            timeIntervalSinceReferenceDate:
                (earliest.timeIntervalSinceReferenceDate / quarterHour).rounded(.up) * quarterHour
        )
    }

    /// Lower bound for the picker. Kept a minute ahead of `now` so a start time chosen right
    /// before tapping Create still clears the server's "must be in the future" check.
    static func earliestStartDate(from now: Date = Date()) -> Date {
        now.addingTimeInterval(60)
    }

    /// Formats available for the selected session type
    var availableFormats: [GameFormat] {
        if isRoundRobin {
            return [.singles, .doubles, .mixedDoubles]
        }
        return GameFormat.allCases
    }

    func createGame(lat: Double?, lng: Double?) async -> CreatedSessionInfo? {
        errorMessage = nil

        // Catches a form that sat open long enough for its start time to go stale, rather
        // than spending a round trip to be told the time is in the past.
        guard selectedDate > Date() else {
            errorMessage = "Start time is in the past. Pick a later time."
            return nil
        }

        isLoading = true
        do {
            try await GameService.createGame(
                gameDatetime: selectedDate,
                spotsAvailable: spotsAvailable,
                gameFormat: gameFormat,
                sessionName: sessionName.isEmpty ? nil : sessionName,
                locationName: locationName.isEmpty ? nil : locationName,
                latitude: selectedLatitude ?? lat,
                longitude: selectedLongitude ?? lng,
                skillLevelMin: skillLevelMin > 0 ? skillLevelMin : nil,
                skillLevelMax: nil,
                description: description.isEmpty ? nil : description,
                sessionType: sessionType,
                numRounds: isRoundRobin ? numRounds : nil,
                friendsOnly: friendsOnly
            )
            let info = CreatedSessionInfo(
                sessionName: sessionName,
                sessionType: sessionType,
                gameFormat: gameFormat,
                spotsAvailable: spotsAvailable,
                locationName: locationName.isEmpty ? nil : locationName
            )
            showingSuccess = true
            resetForm()
            isLoading = false
            return info
        } catch {
            errorMessage = error.userFacingMessage
        }
        isLoading = false
        return nil
    }

    func resetForm() {
        sessionName = ""
        locationName = ""
        selectedLatitude = nil
        selectedLongitude = nil
        selectedDate = Self.defaultStartDate()
        skillLevelMin = 0.0
        gameFormat = .doubles
        spotsAvailable = 4
        numRounds = 5
        description = ""
        friendsOnly = false
    }
}
