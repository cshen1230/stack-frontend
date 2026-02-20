import Foundation
import Supabase

enum TournamentService {
    static func nearbyTournaments(lat: Double, lng: Double, radiusMiles: Double = 50) async throws -> [Tournament] {
        try await supabase.rpc(
            "nearby_tournaments",
            params: ["lat": lat, "lng": lng, "radius_miles": radiusMiles]
        ).execute().value
    }

    static func allUpcoming() async throws -> [Tournament] {
        let today = ISO8601DateFormatter().string(from: Date())
        return try await supabase
            .from("tournaments")
            .select()
            .gte("start_date", value: today)
            .order("start_date")
            .limit(100)
            .execute()
            .value
    }
}
