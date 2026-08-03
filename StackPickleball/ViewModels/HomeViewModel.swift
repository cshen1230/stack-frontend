import SwiftUI

@Observable
class HomeViewModel {
    /// Friends' usual availability, keyed by Calendar weekday (1 = Sunday).
    var schedulesByWeekday: [Int: [FriendScheduleRow]] = [:]
    var nearbyGames: [Game] = []
    /// Sessions you're already in, so the planner can block those hours off rather than
    /// offering you a slot you're busy for.
    var mySessions: [Game] = []
    var participantAvatars: [UUID: [String]] = [:]
    /// Slots worth proposing outright, so the common case doesn't need the calendar at all.
    var suggestions: [SessionSuggestion] = []
    /// Your own recurring times. Held here only to compute suggestions — the planner keeps its
    /// own copy because it also edits them.
    private var mySchedule: [UserSchedule] = []
    var joinedGameIds: Set<UUID> = []
    var isLoading = false
    var errorMessage: String?
    var joinedGame: Game?

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
            // Nearby is a fixed radius now — a picker for it was a setting nobody wanted to
            // manage, and the answer people actually want is "near me".
            async let fetchedGames = GameService.nearbyGames(lat: latitude, lng: longitude)

            if let userId = currentUserId {
                async let fetchedSchedules = ScheduleService.friendsSchedulesByWeekday(userId: userId)
                async let fetchedIds = GameService.myJoinedGameIds(userId: userId)
                async let fetchedMine = MessageService.myActiveSessions(userId: userId)
                async let fetchedOwnTimes = ScheduleService.getMySchedule(userId: userId)

                let allGames = try await fetchedGames
                let joined = try await fetchedIds
                joinedGameIds = joined
                nearbyGames = allGames.filter { !joined.contains($0.id) && $0.creatorId != userId }

                schedulesByWeekday = try await fetchedSchedules
                mySessions = try await fetchedMine
                mySchedule = (try? await fetchedOwnTimes) ?? []

                suggestions = SessionSuggestion.best(
                    friendSchedules: schedulesByWeekday,
                    mySchedule: mySchedule,
                    busy: mySessions
                )
            } else {
                mySessions = []
                suggestions = []
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
