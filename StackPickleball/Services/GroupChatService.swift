import Foundation
import Supabase

enum GroupChatService {

    // MARK: - Queries

    static func myGroupChats(userId: UUID) async throws -> [GroupChat] {
        try await supabase.rpc(
            "my_group_chats",
            params: ["p_user_id": userId.uuidString]
        ).execute().value
    }

    static func groupChatForGame(gameId: UUID) async throws -> GroupChat? {
        let results: [GroupChat] = try await supabase
            .from("group_chats")
            .select("*")
            .eq("game_id", value: gameId)
            .limit(1)
            .execute()
            .value
        return results.first
    }

    static func members(groupChatId: UUID) async throws -> [GroupChatMember] {
        try await supabase
            .from("group_chat_members")
            .select("id, group_chat_id, user_id, role, joined_at, users(first_name, last_name, avatar_url, dupr_rating)")
            .eq("group_chat_id", value: groupChatId)
            .order("joined_at")
            .execute()
            .value
    }

    static func messages(groupChatId: UUID, limit: Int = 50) async throws -> [GroupChatMessage] {
        let results: [GroupChatMessage] = try await supabase
            .from("group_chat_messages")
            .select("id, group_chat_id, user_id, content, message_type, shared_game_id, created_at, users(first_name, last_name, avatar_url)")
            .eq("group_chat_id", value: groupChatId)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return results.reversed()
    }

    static func messagesBefore(groupChatId: UUID, before: Date, limit: Int = 50) async throws -> [GroupChatMessage] {
        let results: [GroupChatMessage] = try await supabase
            .from("group_chat_messages")
            .select("id, group_chat_id, user_id, content, message_type, shared_game_id, created_at, users(first_name, last_name, avatar_url)")
            .eq("group_chat_id", value: groupChatId)
            .lt("created_at", value: ISO8601DateFormatter().string(from: before))
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return results.reversed()
    }

    static func messagesAfter(groupChatId: UUID, after: Date) async throws -> [GroupChatMessage] {
        try await supabase
            .from("group_chat_messages")
            .select("id, group_chat_id, user_id, content, message_type, shared_game_id, created_at, users(first_name, last_name, avatar_url)")
            .eq("group_chat_id", value: groupChatId)
            .gt("created_at", value: ISO8601DateFormatter().string(from: after))
            .order("created_at")
            .limit(100)
            .execute()
            .value
    }

    static func lastMessage(groupChatId: UUID) async throws -> GroupChatMessage? {
        let results: [GroupChatMessage] = try await supabase
            .from("group_chat_messages")
            .select("id, group_chat_id, user_id, content, message_type, shared_game_id, created_at, users(first_name, last_name, avatar_url)")
            .eq("group_chat_id", value: groupChatId)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return results.first
    }

    // MARK: - Mutations

    struct NewGroupChatMessage: Encodable {
        let group_chat_id: UUID
        let user_id: UUID
        let content: String
        let message_type: String
        var shared_game_id: UUID?
    }

    static func sendMessage(groupChatId: UUID, content: String) async throws {
        let session = try await supabase.auth.session
        try await supabase
            .from("group_chat_messages")
            .insert(NewGroupChatMessage(
                group_chat_id: groupChatId,
                user_id: session.user.id,
                content: content,
                message_type: GroupChatMessageType.text.rawValue
            ))
            .execute()
    }

    static func shareSession(groupChatId: UUID, gameId: UUID, content: String) async throws {
        let session = try await supabase.auth.session
        try await supabase
            .from("group_chat_messages")
            .insert(NewGroupChatMessage(
                group_chat_id: groupChatId,
                user_id: session.user.id,
                content: content,
                message_type: GroupChatMessageType.sessionShare.rawValue,
                shared_game_id: gameId
            ))
            .execute()
    }

    // MARK: - Edge Functions

    struct CreateGroupChatRequest: Encodable {
        let name: String
        let member_ids: [String]
    }

    static func createGroupChat(name: String, memberIds: [UUID]) async throws {
        let session = try await supabase.auth.session
        let headers = ["Authorization": "Bearer \(session.accessToken)"]
        try await supabase.functions.invoke(
            "create-group-chat",
            options: .init(
                headers: headers,
                body: CreateGroupChatRequest(
                    name: name,
                    member_ids: memberIds.map(\.uuidString)
                )
            )
        )
    }

    struct AddMemberRequest: Encodable {
        let group_chat_id: String
        let user_id: String
    }

    static func addMember(groupChatId: UUID, userId: UUID) async throws {
        let session = try await supabase.auth.session
        let headers = ["Authorization": "Bearer \(session.accessToken)"]
        try await supabase.functions.invoke(
            "add-group-chat-member",
            options: .init(
                headers: headers,
                body: AddMemberRequest(
                    group_chat_id: groupChatId.uuidString,
                    user_id: userId.uuidString
                )
            )
        )
    }

    struct RemoveMemberRequest: Encodable {
        let group_chat_id: String
        let user_id: String
    }

    static func removeMember(groupChatId: UUID, userId: UUID) async throws {
        let session = try await supabase.auth.session
        let headers = ["Authorization": "Bearer \(session.accessToken)"]
        try await supabase.functions.invoke(
            "remove-group-chat-member",
            options: .init(
                headers: headers,
                body: RemoveMemberRequest(
                    group_chat_id: groupChatId.uuidString,
                    user_id: userId.uuidString
                )
            )
        )
    }

    struct LeaveGroupChatRequest: Encodable {
        let group_chat_id: String
    }

    static func leaveGroupChat(groupChatId: UUID) async throws {
        let session = try await supabase.auth.session
        let headers = ["Authorization": "Bearer \(session.accessToken)"]
        try await supabase.functions.invoke(
            "leave-group-chat",
            options: .init(
                headers: headers,
                body: LeaveGroupChatRequest(group_chat_id: groupChatId.uuidString)
            )
        )
    }

    struct DeleteGroupChatRequest: Encodable {
        let group_chat_id: String
    }

    static func deleteGroupChat(groupChatId: UUID) async throws {
        let session = try await supabase.auth.session
        let headers = ["Authorization": "Bearer \(session.accessToken)"]
        try await supabase.functions.invoke(
            "delete-group-chat",
            options: .init(
                headers: headers,
                body: DeleteGroupChatRequest(group_chat_id: groupChatId.uuidString)
            )
        )
    }

    struct RenameGroupChatRequest: Encodable {
        let group_chat_id: String
        let name: String
    }

    static func renameGroupChat(groupChatId: UUID, name: String) async throws {
        let session = try await supabase.auth.session
        let headers = ["Authorization": "Bearer \(session.accessToken)"]
        try await supabase.functions.invoke(
            "rename-group-chat",
            options: .init(
                headers: headers,
                body: RenameGroupChatRequest(
                    group_chat_id: groupChatId.uuidString,
                    name: name
                )
            )
        )
    }
}
