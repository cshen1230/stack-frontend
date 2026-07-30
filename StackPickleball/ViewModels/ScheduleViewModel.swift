import SwiftUI

struct ScheduleWindowDraft: Identifiable {
    let id = UUID()
    var startTime: Date
    var endTime: Date
    var preferredFormat: GameFormat?
}

@Observable
class ScheduleViewModel {
    // My schedule
    var mySchedule: [UserSchedule] = []
    var editingWindows: [Int: [ScheduleWindowDraft]] = [:]  // dayOfWeek → drafts

    // Friends' schedules
    var selectedDayOfWeek: Int = {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday - 1  // Calendar weekday is 1-based (Sun=1), we use 0-based
    }()
    var friendSchedules: [FriendScheduleRow] = []
    var friendsReady: [ReadyFriend] = []

    // Upcoming sessions
    var upcomingSessions: [Game] = []
    var participantAvatars: [UUID: [String]] = [:]
    var groupChatIds: [UUID: UUID] = [:]

    var isLoading = false
    var errorMessage: String?

    func loadSchedule(userId: UUID) async {
        isLoading = true
        do {
            async let fetchSchedule = ScheduleService.getMySchedule(userId: userId)
            async let fetchSessions = MessageService.myActiveSessions(userId: userId)

            mySchedule = try await fetchSchedule
            upcomingSessions = try await fetchSessions

            // Build editing windows from saved schedule
            editingWindows = [:]
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"
            for window in mySchedule {
                let startDate = timeFormatter.date(from: window.startTime) ?? Date()
                let endDate = timeFormatter.date(from: window.endTime) ?? Date()
                let draft = ScheduleWindowDraft(
                    startTime: startDate,
                    endTime: endDate,
                    preferredFormat: window.preferredFormat
                )
                editingWindows[window.dayOfWeek, default: []].append(draft)
            }

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

    func saveSchedule() async {
        var windows: [ScheduleService.ScheduleWindow] = []
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        for (day, drafts) in editingWindows {
            for draft in drafts {
                windows.append(ScheduleService.ScheduleWindow(
                    day_of_week: day,
                    start_time: timeFormatter.string(from: draft.startTime),
                    end_time: timeFormatter.string(from: draft.endTime),
                    preferred_format: draft.preferredFormat?.rawValue
                ))
            }
        }

        do {
            try await ScheduleService.saveSchedule(windows: windows)
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    func loadFriendSchedules(userId: UUID) async {
        do {
            async let fetchReady = ScheduleService.friendsReadyToPlay(userId: userId)
            async let fetchSchedules = ScheduleService.friendsSchedules(userId: userId, dayOfWeek: selectedDayOfWeek)

            friendsReady = try await fetchReady
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
