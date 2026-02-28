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
        var session_type: String?
        var num_rounds: Int?
        var friends_only: Bool
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
        description: String?,
        sessionType: SessionType = .casual,
        numRounds: Int? = nil,
        friendsOnly: Bool = false
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
            description: description,
            session_type: sessionType.rawValue,
            num_rounds: numRounds,
            friends_only: friendsOnly
        )
        try await supabase.functions.invoke("create-game", options: .init(headers: headers, body: request))
    }

    // MARK: - Round Robin

    struct StartRoundRobinRequest: Encodable {
        let game_id: UUID
        let rounds: [RoundMatchPayload]
    }

    struct RoundMatchPayload: Encodable {
        let round_number: Int
        let court_number: Int
        let team1_player1: UUID
        let team1_player2: UUID?
        let team2_player1: UUID
        let team2_player2: UUID?
        let bye_players: [UUID]
    }

    static func startRoundRobin(gameId: UUID, rounds: [RoundMatchPayload]) async throws {
        // Insert all round rows directly
        struct RoundRow: Encodable {
            let game_id: UUID
            let round_number: Int
            let court_number: Int
            let team1_player1: UUID
            let team1_player2: UUID?
            let team2_player1: UUID
            let team2_player2: UUID?
            let bye_players: [UUID]
        }

        let rows = rounds.map { r in
            RoundRow(
                game_id: gameId,
                round_number: r.round_number,
                court_number: r.court_number,
                team1_player1: r.team1_player1,
                team1_player2: r.team1_player2,
                team2_player1: r.team2_player1,
                team2_player2: r.team2_player2,
                bye_players: r.bye_players
            )
        }

        try await supabase.from("round_robin_rounds").insert(rows).execute()

        // Update game status to in_progress
        try await supabase.from("games")
            .update(["round_robin_status": "in_progress"])
            .eq("id", value: gameId)
            .execute()
    }

    static func submitRoundScore(roundId: UUID, team1Score: Int, team2Score: Int) async throws {
        try await supabase.from("round_robin_rounds")
            .update([
                "team1_score": team1Score,
                "team2_score": team2Score
            ])
            .eq("id", value: roundId)
            .execute()
    }

    static func roundRobinRounds(gameId: UUID) async throws -> [RoundRobinRound] {
        try await supabase
            .from("round_robin_rounds")
            .select()
            .eq("game_id", value: gameId)
            .order("round_number")
            .order("court_number")
            .execute()
            .value
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

    /// Fetches a single game by ID (with creator profile info).
    static func fetchGame(gameId: UUID) async throws -> Game {
        struct GameRow: Decodable {
            let id: UUID
            let creatorId: UUID
            let gameDatetime: Date
            let locationName: String?
            let skillLevelMin: Double?
            let skillLevelMax: Double?
            let spotsAvailable: Int
            let spotsFilled: Int
            let gameFormat: GameFormat
            let sessionName: String?
            let sessionType: SessionType?
            let numRounds: Int?
            let roundRobinStatus: RoundRobinStatus?
            let description: String?
            let isCancelled: Bool
            let friendsOnly: Bool
            let createdAt: Date
            let updatedAt: Date
            let latitude: Double?
            let longitude: Double?
            let users: CreatorInfo

            struct CreatorInfo: Decodable {
                let username: String?
                let firstName: String?
                let lastName: String?

                enum CodingKeys: String, CodingKey {
                    case username
                    case firstName = "first_name"
                    case lastName = "last_name"
                }
            }

            enum CodingKeys: String, CodingKey {
                case id, description, latitude, longitude, users
                case friendsOnly = "friends_only"
                case creatorId = "creator_id"
                case gameDatetime = "game_datetime"
                case locationName = "location_name"
                case skillLevelMin = "skill_level_min"
                case skillLevelMax = "skill_level_max"
                case spotsAvailable = "spots_available"
                case spotsFilled = "spots_filled"
                case gameFormat = "game_format"
                case sessionName = "session_name"
                case sessionType = "session_type"
                case numRounds = "num_rounds"
                case roundRobinStatus = "round_robin_status"
                case isCancelled = "is_cancelled"
                case createdAt = "created_at"
                case updatedAt = "updated_at"
            }
        }

        let row: GameRow = try await supabase
            .from("games")
            .select("*, users(username, first_name, last_name)")
            .eq("id", value: gameId)
            .single()
            .execute()
            .value

        return Game(
            id: row.id,
            creatorId: row.creatorId,
            gameDatetime: row.gameDatetime,
            locationName: row.locationName,
            skillLevelMin: row.skillLevelMin,
            skillLevelMax: row.skillLevelMax,
            spotsAvailable: row.spotsAvailable,
            spotsFilled: row.spotsFilled,
            gameFormat: row.gameFormat,
            sessionName: row.sessionName,
            sessionType: row.sessionType,
            numRounds: row.numRounds,
            roundRobinStatus: row.roundRobinStatus,
            description: row.description,
            isCancelled: row.isCancelled,
            friendsOnly: row.friendsOnly,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
            latitude: row.latitude,
            longitude: row.longitude,
            creatorUsername: row.users.username,
            creatorFirstName: row.users.firstName,
            creatorLastName: row.users.lastName
        )
    }

    /// Returns the current creator_id for a game.
    static func gameCreatorId(gameId: UUID) async throws -> UUID {
        struct Row: Decodable { let creatorId: UUID }
        let row: Row = try await supabase
            .from("games")
            .select("creator_id")
            .eq("id", value: gameId)
            .single()
            .execute()
            .value
        return row.creatorId
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
