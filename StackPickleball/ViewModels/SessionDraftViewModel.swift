import SwiftUI

/// Backs the sheet that pops up after you block out a time on the planner. Everything here is
/// either implied by the drag or has a sane default — the only things worth a decision are the
/// session type and who's coming.
@Observable
class SessionDraftViewModel {
    var range: ClosedRange<Date>
    var sessionType: SessionType = .casual
    var gameFormat: GameFormat = .doubles
    var numRounds: Int = 5

    var locationName: String
    var latitude: Double?
    var longitude: Double?

    /// Friends free for the whole slot — offered first, and pre-selected, since they're the
    /// reason you drew this block.
    var freeThen: [ReadyFriend] = []
    var otherFriends: [FriendRow] = []
    var searchResults: [User] = []
    var searchQuery = "" {
        didSet { if searchQuery.isEmpty { searchResults = [] } }
    }

    var invitedIds: Set<UUID> = []
    var invitedNames: [UUID: String] = [:]

    var isSearching = false
    var isCreating = false
    var errorMessage: String?

    init(range: ClosedRange<Date>, locationName: String = "", latitude: Double? = nil, longitude: Double? = nil) {
        self.range = range
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
    }

    var isRoundRobin: Bool { sessionType == .roundRobin }

    var availableFormats: [GameFormat] {
        isRoundRobin ? [.singles, .doubles, .mixedDoubles] : GameFormat.allCases
    }

    /// Court size, unless you've invited more people than that — then make room for them.
    var spotsAvailable: Int {
        max(gameFormat.defaultPlayerCount, invitedIds.count + 1)
    }

    var rangeLabel: String {
        let start = range.lowerBound.formatted(date: .omitted, time: .shortened)
        let end = range.upperBound.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }

    var dayLabel: String {
        range.lowerBound.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    func isInvited(_ id: UUID) -> Bool { invitedIds.contains(id) }

    func toggleInvite(id: UUID, name: String) {
        if invitedIds.contains(id) {
            invitedIds.remove(id)
        } else {
            invitedIds.insert(id)
            invitedNames[id] = name
        }
    }

    // MARK: - Loading

    func load(currentUserId: UUID?, readyFriends: [ReadyFriend]) async {
        freeThen = DayPlan.friends(readyFriends, freeDuring: range)
        for friend in freeThen {
            invitedIds.insert(friend.userId)
            invitedNames[friend.userId] = friend.displayName
        }

        guard let currentUserId else { return }
        do {
            let rows = try await FriendService.getFriends(userId: currentUserId)
            let freeIds = Set(freeThen.map(\.userId))
            otherFriends = rows.filter { !freeIds.contains($0.friendUserId) }
        } catch {
            // A missing friend list shouldn't block creating the session.
            otherFriends = []
        }
    }

    func search(currentUserId: UUID?) async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            searchResults = []
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            let known = Set(freeThen.map(\.userId))
                .union(otherFriends.map(\.friendUserId))
            searchResults = try await PlayerService.searchPlayers(query: query)
                .filter { $0.id != currentUserId && !known.contains($0.id) }
        } catch {
            if !error.isCancellation { errorMessage = error.userFacingMessage }
        }
    }

    // MARK: - Create

    /// Creates the session and sends every invite. Returns the info for the confirmation toast,
    /// or nil if creation failed.
    func create() async -> CreatedSessionInfo? {
        guard range.lowerBound > Date() else {
            errorMessage = "That time has already passed. Pick a later slot."
            return nil
        }

        isCreating = true
        defer { isCreating = false }

        do {
            let gameId = try await GameService.createGame(
                gameDatetime: range.lowerBound,
                spotsAvailable: spotsAvailable,
                gameFormat: gameFormat,
                sessionName: nil,
                locationName: locationName.isEmpty ? nil : locationName,
                latitude: latitude,
                longitude: longitude,
                skillLevelMin: nil,
                skillLevelMax: nil,
                description: nil,
                sessionType: sessionType,
                numRounds: isRoundRobin ? numRounds : nil,
                friendsOnly: false
            )

            // Invites are best-effort: the session exists either way, and failing the whole
            // thing because one invite bounced would be worse than a partial guest list.
            var failed = 0
            for id in invitedIds {
                do {
                    try await FriendService.inviteToGame(gameId: gameId, friendId: id)
                } catch {
                    failed += 1
                }
            }
            if failed > 0 {
                errorMessage = "Session created, but \(failed) invite\(failed == 1 ? "" : "s") couldn't be sent."
            }

            return CreatedSessionInfo(
                headline: rangeLabel,
                sessionType: sessionType,
                gameFormat: gameFormat,
                spotsAvailable: spotsAvailable,
                locationName: locationName.isEmpty ? nil : locationName
            )
        } catch {
            errorMessage = error.userFacingMessage
            return nil
        }
    }
}
