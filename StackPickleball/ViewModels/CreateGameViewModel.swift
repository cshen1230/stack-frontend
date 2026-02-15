import SwiftUI

@Observable
class CreateGameViewModel {
    var locationName = ""
    var selectedDate = Date()
    var skillLevelMin: Double = 3.0
    var skillLevelMax: Double = 4.5
    var gameFormat: GameFormat = .doubles
    var spotsAvailable: Int = 4
    var description = ""

    var isLoading = false
    var errorMessage: String?
    var showingSuccess = false

    func createGame(lat: Double?, lng: Double?) async {
        isLoading = true
        errorMessage = nil
        do {
            try await GameService.createGame(
                gameDatetime: selectedDate,
                spotsAvailable: spotsAvailable,
                gameFormat: gameFormat,
                locationName: locationName.isEmpty ? nil : locationName,
                latitude: lat,
                longitude: lng,
                skillLevelMin: skillLevelMin,
                skillLevelMax: skillLevelMax,
                description: description.isEmpty ? nil : description
            )
            showingSuccess = true
            resetForm()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func resetForm() {
        locationName = ""
        selectedDate = Date()
        skillLevelMin = 3.0
        skillLevelMax = 4.5
        gameFormat = .doubles
        spotsAvailable = 4
        description = ""
    }
}
