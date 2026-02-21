import SwiftUI

enum DiscoverFilter: String, CaseIterable {
    case both = "All"
    case sessions = "Sessions"
    case players = "Players"
}

@Observable
class DiscoverViewModel {
    var games: [Game] = []
    var joinedGameIds: Set<UUID> = []
    var participantAvatars: [UUID: [String]] = [:]
    var isLoading = false
    var errorMessage: String?

    var selectedDistance: Double = 20.0

    // Available players
    var availablePlayers: [AvailablePlayer] = []
    var discoverFilter: DiscoverFilter = .both
    var isCurrentUserAvailable = false
    var currentUserNote: String? = nil

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
            async let fetchedPlayers = PlayerService.nearbyAvailablePlayers(
                lat: latitude,
                lng: longitude,
                radiusMiles: selectedDistance
            )
            if let userId = currentUserId {
                async let fetchedIds = GameService.myJoinedGameIds(userId: userId)
                let allGames = try await fetchedGames
                // Exclude games the current user created
                games = allGames.filter { $0.creatorId != userId }
                joinedGameIds = try await fetchedIds
            } else {
                games = try await fetchedGames
            }
            availablePlayers = try await fetchedPlayers

            // Check if current user is in the available players list
            if let userId = currentUserId {
                if let currentPlayer = availablePlayers.first(where: { $0.userId == userId }) {
                    isCurrentUserAvailable = true
                    currentUserNote = currentPlayer.note
                } else {
                    isCurrentUserAvailable = false
                    currentUserNote = nil
                }
            }

            // Batch-fetch participant avatars for all loaded games
            let gameIds = games.map(\.id)
            participantAvatars = try await GameService.participantAvatarsForGames(gameIds: gameIds)
        } catch where error.isCancellation {
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func setAvailability(note: String?, availableUntil: Date, preferredFormat: GameFormat?, lat: Double?, lng: Double?) async {
        do {
            try await PlayerService.setAvailability(
                availableUntil: availableUntil,
                latitude: lat,
                longitude: lng,
                preferredFormat: preferredFormat,
                note: note
            )
            await loadGames(lat: lastLat, lng: lastLng, currentUserId: lastUserId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearAvailability() async {
        do {
            try await PlayerService.clearAvailability()
            isCurrentUserAvailable = false
            currentUserNote = nil
            await loadGames(lat: lastLat, lng: lastLng, currentUserId: lastUserId)
        } catch {
            errorMessage = error.localizedDescription
        }
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
