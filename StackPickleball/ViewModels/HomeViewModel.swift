import SwiftUI

@Observable
class HomeViewModel {
    var readyFriends: [ReadyFriend] = []
    var nearbyGames: [Game] = []
    var participantAvatars: [UUID: [String]] = [:]
    var joinedGameIds: Set<UUID> = []
    var currentAvailability: AvailablePlayer?
    var isLoading = false
    var errorMessage: String?
    var joinedGame: Game?

    var selectedDistance: Double = 20.0

    private var lastLat: Double?
    private var lastLng: Double?
    private var lastUserId: UUID?

    /// Your window is open right now — as opposed to `currentAvailability` merely existing,
    /// which only means you've broadcast a window that may not have started yet.
    func isCurrentUserReadyNow(at now: Date = Date()) -> Bool {
        currentAvailability?.isActive(at: now) ?? false
    }

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
                async let fetchedReady = ScheduleService.friendsReadyToPlay(userId: userId)
                async let fetchedIds = GameService.myJoinedGameIds(userId: userId)

                let allGames = try await fetchedGames
                let joined = try await fetchedIds
                joinedGameIds = joined
                nearbyGames = allGames.filter { !joined.contains($0.id) && $0.creatorId != userId }

                // Every window that hasn't expired, near or far — the planner lets you page
                // through days, so filtering to today here would leave the rest blank. Each
                // day's calendar picks out what belongs to it.
                readyFriends = try await fetchedReady
                    .sorted { $0.windowStart < $1.windowStart }

                // Check own availability
                currentAvailability = try? await PlayerService.currentUserAvailability(userId: userId)
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

    func broadcastReady(
        from: Date,
        until: Date,
        format: GameFormat?,
        note: String?,
        lat: Double?,
        lng: Double?
    ) async {
        do {
            try await PlayerService.setAvailability(
                availableFrom: from,
                availableUntil: until,
                latitude: lat,
                longitude: lng,
                preferredFormat: format,
                note: note
            )
            // loadHome re-reads the window we just wrote, so the banner reflects whether it
            // has actually started rather than assuming it has.
            await loadHome(currentUserId: lastUserId, lat: lastLat, lng: lastLng)
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    func stopReady() async {
        do {
            try await PlayerService.clearAvailability()
            currentAvailability = nil
            await loadHome(currentUserId: lastUserId, lat: lastLat, lng: lastLng)
        } catch {
            errorMessage = error.userFacingMessage
        }
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
