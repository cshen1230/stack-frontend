import Foundation
import Supabase

enum GameService {
    static func nearbyGames(lat: Double, lng: Double, radiusMiles: Double = 20) async throws -> [Game] {
        try await supabase.rpc(
            "nearby_games",
            params: ["lat": lat, "lng": lng, "radius_miles": radiusMiles]
        ).execute().value
    }

    struct CreateGameRequest: Encodable {
        let game_datetime: String
        let spots_available: Int
        let game_format: String
        var session_name: String?
        var location_name: String?
        var latitude: Double?
        var longitude: Double?
        var skill_level_min: Double?
        var skill_level_max: Double?
        var description: String?
    }

    static func createGame(
        gameDatetime: Date,
        spotsAvailable: Int,
        gameFormat: GameFormat,
        sessionName: String?,
        locationName: String?,
        latitude: Double?,
        longitude: Double?,
        skillLevelMin: Double?,
        skillLevelMax: Double?,
        description: String?
    ) async throws {
        let session = try await supabase.auth.session
        let headers = ["Authorization": "Bearer \(session.accessToken)"]
        let request = CreateGameRequest(
            game_datetime: ISO8601DateFormatter().string(from: gameDatetime),
            spots_available: spotsAvailable,
            game_format: gameFormat.rawValue,
            session_name: sessionName,
            location_name: locationName,
            latitude: latitude,
            longitude: longitude,
            skill_level_min: skillLevelMin,
            skill_level_max: skillLevelMax,
            description: description
        )
        try await supabase.functions.invoke("create-game", options: .init(headers: headers, body: request))
    }

    struct GameIdRequest: Encodable {
        let game_id: String
    }

    static func rsvpToGame(gameId: UUID) async throws {
        let session = try await supabase.auth.session
        let headers = ["Authorization": "Bearer \(session.accessToken)"]
        try await supabase.functions.invoke(
            "rsvp-to-game",
            options: .init(headers: headers, body: GameIdRequest(game_id: gameId.uuidString))
        )
    }

    static func cancelRsvp(gameId: UUID) async throws {
        let session = try await supabase.auth.session
        let headers = ["Authorization": "Bearer \(session.accessToken)"]
        try await supabase.functions.invoke(
            "cancel-rsvp",
            options: .init(headers: headers, body: GameIdRequest(game_id: gameId.uuidString))
        )
    }

    struct KickPlayerRequest: Encodable {
        let game_id: String
        let user_id: String
    }

    static func kickPlayer(gameId: UUID, userId: UUID) async throws {
        let session = try await supabase.auth.session
        let headers = ["Authorization": "Bearer \(session.accessToken)"]
        try await supabase.functions.invoke(
            "kick-player",
            options: .init(headers: headers, body: KickPlayerRequest(game_id: gameId.uuidString, user_id: userId.uuidString))
        )
    }

    struct TransferOwnershipRequest: Encodable {
        let game_id: String
        let new_owner_id: String
    }

    static func transferOwnership(gameId: UUID, newOwnerId: UUID) async throws {
        let session = try await supabase.auth.session
        let headers = ["Authorization": "Bearer \(session.accessToken)"]
        try await supabase.functions.invoke(
            "transfer-ownership",
            options: .init(headers: headers, body: TransferOwnershipRequest(game_id: gameId.uuidString, new_owner_id: newOwnerId.uuidString))
        )
    }

    static func deleteGame(gameId: UUID) async throws {
        let session = try await supabase.auth.session
        let headers = ["Authorization": "Bearer \(session.accessToken)"]
        try await supabase.functions.invoke(
            "cancel-game",
            options: .init(headers: headers, body: GameIdRequest(game_id: gameId.uuidString))
        )
    }

    /// Returns past games the user hosted or joined.
    static func userPastGames(userId: UUID) async throws -> [Game] {
        try await supabase.rpc(
            "user_past_games",
            params: ["p_user_id": userId.uuidString]
        ).execute().value
    }

    /// Returns the set of game IDs where the given user is a confirmed participant.
    static func myJoinedGameIds(userId: UUID) async throws -> Set<UUID> {
        let participants: [GameParticipant] = try await supabase
            .from("game_participants")
            .select()
            .eq("user_id", value: userId)
            .eq("rsvp_status", value: "confirmed")
            .execute()
            .value
        return Set(participants.map(\.gameId))
    }

    /// Returns participants for a specific game, joined with user profile info.
    static func gameParticipants(gameId: UUID) async throws -> [ParticipantWithProfile] {
        let rows: [ParticipantWithProfile] = try await supabase
            .from("game_participants")
            .select("id, game_id, user_id, rsvp_status, created_at, users(username, first_name, last_name, dupr_rating, avatar_url)")
            .eq("game_id", value: gameId)
            .eq("rsvp_status", value: "confirmed")
            .execute()
            .value
        return rows
    }

    /// Returns participant summaries (userId, name, avatar) grouped by game ID.
    static func participantSummariesForGames(gameIds: [UUID]) async throws -> [UUID: [ParticipantSummaryRow]] {
        guard !gameIds.isEmpty else { return [:] }
        let rows: [ParticipantSummaryRow] = try await supabase
            .from("game_participants")
            .select("game_id, user_id, users(first_name, last_name, avatar_url)")
            .in("game_id", values: gameIds.map(\.uuidString))
            .eq("rsvp_status", value: "confirmed")
            .execute()
            .value
        var result: [UUID: [ParticipantSummaryRow]] = [:]
        for row in rows {
            result[row.gameId, default: []].append(row)
        }
        return result
    }

    /// Returns avatar URLs grouped by game ID for a batch of games.
    static func participantAvatarsForGames(gameIds: [UUID]) async throws -> [UUID: [String]] {
        guard !gameIds.isEmpty else { return [:] }
        let rows: [ParticipantAvatarRow] = try await supabase
            .from("game_participants")
            .select("game_id, users(avatar_url)")
            .in("game_id", values: gameIds.map(\.uuidString))
            .eq("rsvp_status", value: "confirmed")
            .execute()
            .value
        var result: [UUID: [String]] = [:]
        for row in rows {
            if let url = row.users.avatarUrl {
                result[row.gameId, default: []].append(url)
            }
        }
        return result
    }
}
