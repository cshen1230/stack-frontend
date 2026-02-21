import Foundation
import Supabase

enum FriendService {
    static func getFriends(userId: UUID) async throws -> [FriendRow] {
        try await supabase.rpc(
            "get_friends",
            params: ["p_user_id": userId]
        ).execute().value
    }

    static func getFriendRequests(userId: UUID) async throws -> [FriendRow] {
        try await supabase.rpc(
            "get_friend_requests",
            params: ["p_user_id": userId]
        ).execute().value
    }

    // MARK: - Edge Function Requests

    private struct SendFriendRequestBody: Encodable {
        let friend_id: UUID
    }

    static func sendFriendRequest(friendId: UUID) async throws {
        let session = try await supabase.auth.session
        let headers = ["Authorization": "Bearer \(session.accessToken)"]
        try await supabase.functions.invoke(
            "send-friend-request",
            options: .init(headers: headers, body: SendFriendRequestBody(friend_id: friendId))
        )
    }

    private struct RespondFriendRequestBody: Encodable {
        let friendship_id: UUID
        let action: String
    }

    static func respondToFriendRequest(friendshipId: UUID, accept: Bool) async throws {
        let session = try await supabase.auth.session
        let headers = ["Authorization": "Bearer \(session.accessToken)"]
        try await supabase.functions.invoke(
            "respond-friend-request",
            options: .init(
                headers: headers,
                body: RespondFriendRequestBody(
                    friendship_id: friendshipId,
                    action: accept ? "accept" : "decline"
                )
            )
        )
    }

    private struct RemoveFriendBody: Encodable {
        let friendship_id: UUID
    }

    static func removeFriend(friendshipId: UUID) async throws {
        let session = try await supabase.auth.session
        let headers = ["Authorization": "Bearer \(session.accessToken)"]
        try await supabase.functions.invoke(
            "remove-friend",
            options: .init(headers: headers, body: RemoveFriendBody(friendship_id: friendshipId))
        )
    }

    private struct InviteToGameBody: Encodable {
        let game_id: UUID
        let friend_id: UUID
    }

    static func inviteToGame(gameId: UUID, friendId: UUID) async throws {
        let session = try await supabase.auth.session
        let headers = ["Authorization": "Bearer \(session.accessToken)"]
        try await supabase.functions.invoke(
            "invite-to-game",
            options: .init(
                headers: headers,
                body: InviteToGameBody(game_id: gameId, friend_id: friendId)
            )
        )
    }
}
