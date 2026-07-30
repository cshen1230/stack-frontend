import SwiftUI

@Observable
class ScheduleViewModel {
    // My schedule
    var mySchedule: [UserSchedule] = []
    /// Availability as day-part taps, keyed by Calendar weekday (1 = Sunday).
    var dayPartSelection: [Int: Set<DayPart>] = [:]

    // Friends' schedules
    var selectedDayOfWeek: Int = {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday - 1  // Calendar weekday is 1-based (Sun=1), we use 0-based
    }()
    var friendSchedules: [FriendScheduleRow] = []
    /// Friends' usual availability across the week, for the planner.
    var schedulesByWeekday: [Int: [FriendScheduleRow]] = [:]

    // Upcoming sessions
    var upcomingSessions: [Game] = []
    var participantAvatars: [UUID: [String]] = [:]
    var groupChatIds: [UUID: UUID] = [:]

    var isLoading = false
    var errorMessage: String?

    private var lastUserId: UUID?

    func loadSchedule(userId: UUID) async {
        isLoading = true
        lastUserId = userId
        do {
            async let fetchSchedule = ScheduleService.getMySchedule(userId: userId)
            async let fetchSessions = MessageService.myActiveSessions(userId: userId)
            // The planner is reachable from either section, so the week loads up front.
            async let fetchWeek = ScheduleService.friendsSchedulesByWeekday(userId: userId)

            mySchedule = try await fetchSchedule
            upcomingSessions = try await fetchSessions
            schedulesByWeekday = try await fetchWeek

            dayPartSelection = Self.dayParts(from: mySchedule)

            // Fetch avatars and group chat IDs for sessions
            let gameIds = upcomingSessions.map(\.id)
            participantAvatars = (try? await GameService.participantAvatarsForGames(gameIds: gameIds)) ?? [:]

            await withTaskGroup(of: (UUID, UUID?).self) { group in
                for session in upcomingSessions {
                    group.addTask {
                        let chat = try? await GroupChatService.groupChatForGame(gameId: session.id)
                        return (session.id, chat?.id)
                    }
                }
                for await (gameId, chatId) in group {
                    if let chatId {
                        groupChatIds[gameId] = chatId
                    }
                }
            }
        } catch where error.isCancellation {
            return
        } catch {
            if !Task.isCancelled {
                errorMessage = error.userFacingMessage
            }
        }
        isLoading = false
    }

    /// Reads saved windows back as taps, so reopening the editor shows what you set.
    static func dayParts(from schedule: [UserSchedule]) -> [Int: Set<DayPart>] {
        var result: [Int: Set<DayPart>] = [:]
        for window in schedule {
            guard let startHour = Int(window.startTime.prefix(2)),
                  let endHour = Int(window.endTime.prefix(2)) else { continue }
            // Stored day_of_week is 0-based from Sunday; Calendar's weekday is 1-based.
            let weekday = window.dayOfWeek + 1
            result[weekday, default: []].formUnion(DayPart.parts(coveringHours: startHour, endHour))
        }
        return result
    }

    func saveSchedule() async {
        do {
            try await ScheduleService.saveSchedule(windows: dayPartSelection.scheduleWindows)
            if let lastUserId {
                mySchedule = try await ScheduleService.getMySchedule(userId: lastUserId)
            }
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    func loadFriendSchedules(userId: UUID) async {
        do {
            // The whole week backs the planner; the selected day backs the list below it.
            async let fetchWeek = ScheduleService.friendsSchedulesByWeekday(userId: userId)
            async let fetchSchedules = ScheduleService.friendsSchedules(userId: userId, dayOfWeek: selectedDayOfWeek)

            schedulesByWeekday = try await fetchWeek
            friendSchedules = try await fetchSchedules
        } catch where error.isCancellation {
            return
        } catch {
            if !Task.isCancelled {
                errorMessage = error.userFacingMessage
            }
        }
    }

    func loadUpcomingSessions(userId: UUID) async {
        do {
            upcomingSessions = try await MessageService.myActiveSessions(userId: userId)
            let gameIds = upcomingSessions.map(\.id)
            participantAvatars = (try? await GameService.participantAvatarsForGames(gameIds: gameIds)) ?? [:]
        } catch where error.isCancellation {
            return
        } catch {
            if !Task.isCancelled {
                errorMessage = error.userFacingMessage
            }
        }
    }
}
