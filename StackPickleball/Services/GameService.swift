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
        locationName: String?,
        latitude: Double?,
        longitude: Double?,
        skillLevelMin: Double?,
        skillLevelMax: Double?,
        description: String?
    ) async throws {
        let request = CreateGameRequest(
            game_datetime: ISO8601DateFormatter().string(from: gameDatetime),
            spots_available: spotsAvailable,
            game_format: gameFormat.rawValue,
            location_name: locationName,
            latitude: latitude,
            longitude: longitude,
            skill_level_min: skillLevelMin,
            skill_level_max: skillLevelMax,
            description: description
        )
        try await supabase.functions.invoke("create-game", options: .init(body: request))
    }

    struct GameIdRequest: Encodable {
        let game_id: String
    }

    static func rsvpToGame(gameId: UUID) async throws {
        try await supabase.functions.invoke(
            "rsvp-to-game",
            options: .init(body: GameIdRequest(game_id: gameId.uuidString))
        )
    }

    static func cancelRsvp(gameId: UUID) async throws {
        try await supabase.functions.invoke(
            "cancel-rsvp",
            options: .init(body: GameIdRequest(game_id: gameId.uuidString))
        )
    }
}
