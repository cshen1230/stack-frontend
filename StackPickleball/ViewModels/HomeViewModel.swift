import SwiftUI

@Observable
class HomeViewModel {
    /// Friends' usual availability, keyed by Calendar weekday (1 = Sunday).
    var schedulesByWeekday: [Int: [FriendScheduleRow]] = [:]
    var nearbyGames: [Game] = []
    var participantAvatars: [UUID: [String]] = [:]
    var joinedGameIds: Set<UUID> = []
    var isLoading = false
    var errorMessage: String?
    var joinedGame: Game?

    var selectedDistance: Double = 20.0

    private var lastLat: Double?
    private var lastLng: Double?
    private var lastUserId: UUID?

    func loadHome(currentUserId: UUID?, lat: Double?, lng: Double?) async {
        isLoading = true
        errorMessage = nil
        lastLat = lat
        lastLng = lng
        lastUserId = currentUserId

        let latitude = lat ?? 30.2672
        let longitude = lng ?? -97.7431

        do {
            async let fetchedGames = GameService.nearbyGames(
                lat: latitude,
                lng: longitude,
                radiusMiles: selectedDistance
            )

            if let userId = currentUserId {
                async let fetchedSchedules = ScheduleService.friendsSchedulesByWeekday(userId: userId)
                async let fetchedIds = GameService.myJoinedGameIds(userId: userId)

                let allGames = try await fetchedGames
                let joined = try await fetchedIds
                joinedGameIds = joined
                nearbyGames = allGames.filter { !joined.contains($0.id) && $0.creatorId != userId }

                schedulesByWeekday = try await fetchedSchedules
            } else {
                nearbyGames = try await fetchedGames
            }

            let gameIds = nearbyGames.map(\.id)
            participantAvatars = try await GameService.participantAvatarsForGames(gameIds: gameIds)
        } catch where error.isCancellation {
            return
        } catch {
            if !Task.isCancelled {
                errorMessage = error.userFacingMessage
            }
        }
        isLoading = false
    }

    func rsvpToGame(_ game: Game) async {
        do {
            try await GameService.rsvpToGame(gameId: game.id)
            joinedGameIds.insert(game.id)
            joinedGame = game
            nearbyGames.removeAll { $0.id == game.id }
        } catch {
            errorMessage = error.userFacingMessage
            await loadHome(currentUserId: lastUserId, lat: lastLat, lng: lastLng)
        }
    }
}
