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
        var note: String?
    }

    static func setAvailability(
        availableUntil: Date,
        latitude: Double?,
        longitude: Double?,
        preferredFormat: GameFormat?,
        note: String?
    ) async throws {
        let session = try await supabase.auth.session
        let headers = ["Authorization": "Bearer \(session.accessToken)"]
        let request = SetAvailabilityRequest(
            available_until: ISO8601DateFormatter().string(from: availableUntil),
            latitude: latitude,
            longitude: longitude,
            preferred_format: preferredFormat?.rawValue,
            note: note
        )
        try await supabase.functions.invoke("set-availability", options: .init(headers: headers, body: request))
    }

    static func clearAvailability() async throws {
        let session = try await supabase.auth.session
        let headers = ["Authorization": "Bearer \(session.accessToken)"]
        try await supabase.functions.invoke(
            "set-availability",
            options: .init(method: .delete, headers: headers)
        )
    }

    static func currentUserAvailability(userId: UUID) async throws -> AvailablePlayer? {
        try await supabase
            .from("available_players")
            .select()
            .eq("user_id", value: userId)
            .eq("status", value: "available")
            .gt("available_until", value: ISO8601DateFormatter().string(from: Date()))
            .maybeSingle()
            .execute()
            .value
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
