import Foundation
import Supabase

enum PlayerService {
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
