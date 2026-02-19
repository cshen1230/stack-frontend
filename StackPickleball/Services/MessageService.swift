import Foundation
import Supabase

enum MessageService {
    static func messages(gameId: UUID, limit: Int = 50) async throws -> [GameMessage] {
        let results: [GameMessage] = try await supabase
            .from("game_messages")
            .select("id, game_id, user_id, content, created_at, users(first_name, last_name, avatar_url)")
            .eq("game_id", value: gameId)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return results.reversed()
    }

    static func messagesBefore(gameId: UUID, before: Date, limit: Int = 50) async throws -> [GameMessage] {
        let results: [GameMessage] = try await supabase
            .from("game_messages")
            .select("id, game_id, user_id, content, created_at, users(first_name, last_name, avatar_url)")
            .eq("game_id", value: gameId)
            .lt("created_at", value: ISO8601DateFormatter().string(from: before))
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return results.reversed()
    }

    static func messagesAfter(gameId: UUID, after: Date) async throws -> [GameMessage] {
        try await supabase
            .from("game_messages")
            .select("id, game_id, user_id, content, created_at, users(first_name, last_name, avatar_url)")
            .eq("game_id", value: gameId)
            .gt("created_at", value: ISO8601DateFormatter().string(from: after))
            .order("created_at")
            .limit(100)
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

    static func lastMessage(gameId: UUID) async throws -> GameMessage? {
        let results: [GameMessage] = try await supabase
            .from("game_messages")
            .select("id, game_id, user_id, content, created_at, users(first_name, last_name, avatar_url)")
            .eq("game_id", value: gameId)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return results.first
    }

    static func myActiveSessions(userId: UUID) async throws -> [Game] {
        try await supabase.rpc(
            "my_active_sessions",
            params: ["p_user_id": userId.uuidString]
        ).execute().value
    }
}
