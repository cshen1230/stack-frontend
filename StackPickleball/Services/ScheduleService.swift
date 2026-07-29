import Foundation
import Supabase

enum ScheduleService {

    // MARK: - My Recurring Schedule

    static func getMySchedule(userId: UUID) async throws -> [UserSchedule] {
        try await supabase
            .from("user_schedules")
            .select()
            .eq("user_id", value: userId)
            .order("day_of_week")
            .order("start_time")
            .execute()
            .value
    }

    struct ScheduleWindow: Encodable, Sendable {
        let day_of_week: Int
        let start_time: String
        let end_time: String
        var preferred_format: String?
    }

    struct SaveScheduleRequest: Encodable, Sendable {
        let windows: [ScheduleWindow]
    }

    static func saveSchedule(windows: [ScheduleWindow]) async throws {
        let session = try await supabase.auth.session
        let headers = ["Authorization": "Bearer \(session.accessToken)"]
        try await supabase.functions.invoke(
            "set-schedule",
            options: .init(headers: headers, body: SaveScheduleRequest(windows: windows))
        )
    }

    static func clearSchedule() async throws {
        let session = try await supabase.auth.session
        let headers = ["Authorization": "Bearer \(session.accessToken)"]
        try await supabase.functions.invoke(
            "set-schedule",
            options: .init(method: .delete, headers: headers)
        )
    }

    // MARK: - Friends

    static func friendsReadyToPlay(userId: UUID) async throws -> [ReadyFriend] {
        try await supabase.rpc(
            "friends_ready_to_play",
            params: ["p_user_id": userId.uuidString]
        ).execute().value
    }

    struct FriendsSchedulesParams: Encodable, Sendable {
        let p_user_id: String
        let p_day_of_week: Int
    }

    static func friendsSchedules(userId: UUID, dayOfWeek: Int) async throws -> [FriendScheduleRow] {
        try await supabase.rpc(
            "friends_schedules",
            params: FriendsSchedulesParams(p_user_id: userId.uuidString, p_day_of_week: dayOfWeek)
        ).execute().value
    }

    // MARK: - Device Tokens

    struct DeviceTokenRow: Encodable, Sendable {
        let user_id: String
        let device_token: String
        let platform: String
    }

    static func registerDeviceToken(_ token: String) async throws {
        let session = try await supabase.auth.session
        let userId = session.user.id
        let row = DeviceTokenRow(user_id: userId.uuidString, device_token: token, platform: "ios")
        try await supabase
            .from("user_devices")
            .insert(row)
            .execute()
    }
}
