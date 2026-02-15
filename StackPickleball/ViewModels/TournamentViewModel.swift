import SwiftUI

@Observable
class TournamentViewModel {
    var tournaments: [Tournament] = []
    var isLoading = false
    var errorMessage: String?

    func loadTournaments(lat: Double?, lng: Double?) async {
        isLoading = true
        errorMessage = nil
        do {
            if let lat, let lng {
                tournaments = try await TournamentService.nearbyTournaments(lat: lat, lng: lng)
            } else {
                tournaments = try await TournamentService.allUpcoming()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
