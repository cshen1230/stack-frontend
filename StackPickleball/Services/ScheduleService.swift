import Foundation
import Supabase

enum ScheduleService {

    struct ScheduleWindow {
        let day_of_week: Int
        let start_time: String
        let end_time: String
        var preferred_format: String?
    }

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

    private struct SaveScheduleBody: Encodable {
        let windows: [ScheduleWindowPayload]
    }

    private struct ScheduleWindowPayload: Encodable {
        let day_of_week: Int
        let start_time: String
        let end_time: String
        var preferred_format: String?
    }

    static func saveSchedule(windows: [ScheduleWindow]) async throws {
        let session = try await supabase.auth.session
        let headers = ["Authorization": "Bearer \(session.accessToken)"]
        let payloads = windows.map {
            ScheduleWindowPayload(
                day_of_week: $0.day_of_week,
                start_time: $0.start_time,
                end_time: $0.end_time,
                preferred_format: $0.preferred_format
            )
        }
        try await supabase.functions.invoke(
            "set-schedule",
            options: .init(headers: headers, body: SaveScheduleBody(windows: payloads))
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

    /// Every weekday's friend availability at once, keyed by `Calendar`'s 1-based weekday so
    /// callers can look up a date directly. The planner pages across days, so fetching one day
    /// at a time would put a network round trip behind every tap of the day strip.
    static func friendsSchedulesByWeekday(userId: UUID) async throws -> [Int: [FriendScheduleRow]] {
        try await withThrowingTaskGroup(of: (Int, [FriendScheduleRow]).self) { group in
            // `user_schedules.day_of_week` is 0-based from Sunday; Calendar's weekday is 1-based.
            for storedDay in 0...6 {
                group.addTask {
                    (storedDay + 1, try await friendsSchedules(userId: userId, dayOfWeek: storedDay))
                }
            }
            var result: [Int: [FriendScheduleRow]] = [:]
            for try await (weekday, rows) in group {
                result[weekday] = rows
            }
            return result
        }
    }

    static func friendsSchedules(userId: UUID, dayOfWeek: Int) async throws -> [FriendScheduleRow] {
        // Pass day_of_week as string to keep dict homogeneous (all String values)
        // The RPC accepts INT but Supabase auto-casts from the JSON number
        try await supabase.rpc(
            "friends_schedules",
            params: ["p_user_id": userId.uuidString, "p_day_of_week": "\(dayOfWeek)"]
        ).execute().value
    }

    // MARK: - Device Tokens

    private struct DeviceTokenRow: Encodable {
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
