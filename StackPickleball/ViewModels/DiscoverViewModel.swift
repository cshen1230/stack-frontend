import SwiftUI

@Observable
class DiscoverViewModel {
    var games: [Game] = []
    var joinedGameIds: Set<UUID> = []
    var participantAvatars: [UUID: [String]] = [:]
    var isLoading = false
    var errorMessage: String?

    var selectedDistance: Double = 20.0

    // Track last-used params so we can refresh after RSVP
    private var lastLat: Double?
    private var lastLng: Double?
    private var lastUserId: UUID?

    func loadGames(lat: Double?, lng: Double?, currentUserId: UUID?) async {
        isLoading = true
        errorMessage = nil
        lastLat = lat
        lastLng = lng
        lastUserId = currentUserId
        do {
            let latitude = lat ?? 30.2672
            let longitude = lng ?? -97.7431
            async let fetchedGames = GameService.nearbyGames(
                lat: latitude,
                lng: longitude,
                radiusMiles: selectedDistance
            )
            if let userId = currentUserId {
                async let fetchedIds = GameService.myJoinedGameIds(userId: userId)
                games = try await fetchedGames
                joinedGameIds = try await fetchedIds
            } else {
                games = try await fetchedGames
            }

            // Batch-fetch participant avatars for all loaded games
            let gameIds = games.map(\.id)
            participantAvatars = try await GameService.participantAvatarsForGames(gameIds: gameIds)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func rsvpToGame(_ game: Game) async {
        do {
            try await GameService.rsvpToGame(gameId: game.id)
            // Optimistic update for instant UI feedback
            if let index = games.firstIndex(where: { $0.id == game.id }) {
                games[index].spotsFilled += 1
            }
            joinedGameIds.insert(game.id)
        } catch {
            errorMessage = error.localizedDescription
            // Refresh to get accurate state on error
            await loadGames(lat: lastLat, lng: lastLng, currentUserId: lastUserId)
        }
    }
}
