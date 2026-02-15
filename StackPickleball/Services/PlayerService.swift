import Foundation
import Supabase

enum PlayerService {
    static func nearbyAvailablePlayers(lat: Double, lng: Double, radiusMiles: Double = 20) async throws -> [AvailablePlayer] {
        try await supabase.rpc(
            "nearby_available_players",
            params: ["lat": lat, "lng": lng, "radius_miles": radiusMiles]
        ).execute().value
    }

    struct SetAvailabilityRequest: Encodable {
        let available_until: String
        var latitude: Double?
        var longitude: Double?
        var preferred_format: String?
    }

    static func setAvailability(
        availableUntil: Date,
        latitude: Double?,
        longitude: Double?,
        preferredFormat: GameFormat?
    ) async throws {
        let request = SetAvailabilityRequest(
            available_until: ISO8601DateFormatter().string(from: availableUntil),
            latitude: latitude,
            longitude: longitude,
            preferred_format: preferredFormat?.rawValue
        )
        try await supabase.functions.invoke("set-availability", options: .init(body: request))
    }

    static func clearAvailability() async throws {
        try await supabase.functions.invoke(
            "set-availability",
            options: .init(method: .delete)
        )
    }

    static func searchPlayers(query: String) async throws -> [User] {
        try await supabase
            .from("users")
            .select()
            .or("username.ilike.%\(query)%,first_name.ilike.%\(query)%,last_name.ilike.%\(query)%")
            .limit(20)
            .execute()
            .value
    }
}
