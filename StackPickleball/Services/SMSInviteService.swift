import Foundation
import Supabase

enum SMSInviteService {
    private struct SendSMSInviteBody: Encodable {
        let game_id: UUID
        let invitee_name: String
        let phone_number: String
    }

    static func sendSMSInvite(gameId: UUID, inviteeName: String, phoneNumber: String) async throws {
        let session = try await supabase.auth.session
        let headers = ["Authorization": "Bearer \(session.accessToken)"]
        try await supabase.functions.invoke(
            "send-sms-invite",
            options: .init(
                headers: headers,
                body: SendSMSInviteBody(
                    game_id: gameId,
                    invitee_name: inviteeName,
                    phone_number: phoneNumber
                )
            )
        )
    }

    static func smsInvitations(gameId: UUID) async throws -> [SMSInvitation] {
        try await supabase
            .from("sms_invitations")
            .select()
            .eq("game_id", value: gameId)
            .order("created_at")
            .execute()
            .value
    }
}
