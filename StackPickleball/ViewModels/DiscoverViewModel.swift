import SwiftUI

@Observable
class DiscoverViewModel {
    var games: [Game] = []
    var isLoading = false
    var errorMessage: String?

    var selectedDistance: Double = 20.0

    func loadGames(lat: Double?, lng: Double?) async {
        isLoading = true
        errorMessage = nil
        do {
            let latitude = lat ?? 30.2672
            let longitude = lng ?? -97.7431
            games = try await GameService.nearbyGames(
                lat: latitude,
                lng: longitude,
                radiusMiles: selectedDistance
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func rsvpToGame(_ game: Game) async {
        do {
            try await GameService.rsvpToGame(gameId: game.id)
            if let index = games.firstIndex(where: { $0.id == game.id }) {
                games[index].spotsFilled += 1
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
