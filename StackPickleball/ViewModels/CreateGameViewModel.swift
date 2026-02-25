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
    var selectedDate = Date()
    var skillLevelMin: Double = 0.0
    var gameFormat: GameFormat = .doubles
    var spotsAvailable: Int = 4
    var numRounds: Int = 5
    var description = ""

    var isLoading = false
    var errorMessage: String?
    var showingSuccess = false

    var isRoundRobin: Bool { sessionType == .roundRobin }

    /// Formats available for the selected session type
    var availableFormats: [GameFormat] {
        if isRoundRobin {
            return [.singles, .doubles, .mixedDoubles]
        }
        return GameFormat.allCases
    }

    func createGame(lat: Double?, lng: Double?) async -> CreatedSessionInfo? {
        isLoading = true
        errorMessage = nil
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
                numRounds: isRoundRobin ? numRounds : nil
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
            errorMessage = error.localizedDescription
        }
        isLoading = false
        return nil
    }

    func resetForm() {
        sessionName = ""
        locationName = ""
        selectedLatitude = nil
        selectedLongitude = nil
        selectedDate = Date()
        skillLevelMin = 0.0
        gameFormat = .doubles
        spotsAvailable = 4
        numRounds = 5
        description = ""
    }
}
