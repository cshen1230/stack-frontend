import Foundation
import Supabase

enum MessageService {
    static func messages(gameId: UUID) async throws -> [GameMessage] {
        try await supabase
            .from("game_messages")
            .select("id, game_id, user_id, content, created_at, users(first_name, last_name, avatar_url)")
            .eq("game_id", value: gameId)
            .order("created_at")
            .execute()
            .value
    }

    struct NewMessage: Encodable {
        let game_id: String
        let user_id: String
        let content: String
    }

    static func sendMessage(gameId: UUID, content: String) async throws {
        let session = try await supabase.auth.session
        try await supabase
            .from("game_messages")
            .insert(NewMessage(
                game_id: gameId.uuidString,
                user_id: session.user.id.uuidString,
                content: content
            ))
            .execute()
    }

    static func myActiveSessions(userId: UUID) async throws -> [Game] {
        try await supabase.rpc(
            "my_active_sessions",
            params: ["p_user_id": userId.uuidString]
        ).execute().value
    }
}
