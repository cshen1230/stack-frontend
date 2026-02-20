import SwiftUI

@Observable
class RoundRobinViewModel {
    let game: Game
    var participants: [ParticipantWithProfile] = []
    var rounds: [RoundRobinRound] = []
    var isLoading = true
    var errorMessage: String?

    var leaderboard: [RoundRobinScheduler.LeaderboardEntry] {
        RoundRobinScheduler.computeLeaderboard(rounds: rounds)
    }

    /// Rounds grouped by round number
    var roundGroups: [(number: Int, matches: [RoundRobinRound], byes: [UUID])] {
        let grouped = Dictionary(grouping: rounds) { $0.roundNumber }
        return grouped.keys.sorted().map { num in
            let matches = grouped[num] ?? []
            let byes = matches.first?.byePlayers ?? []
            return (number: num, matches: matches, byes: byes)
        }
    }

    /// Whether all rounds have scores
    var isComplete: Bool {
        !rounds.isEmpty && rounds.allSatisfy(\.hasScore)
    }

    init(game: Game) {
        self.game = game
    }

    func loadData() async {
        isLoading = true
        do {
            async let fetchParticipants = GameService.gameParticipants(gameId: game.id)
            async let fetchRounds = GameService.roundRobinRounds(gameId: game.id)
            participants = try await fetchParticipants
            rounds = try await fetchRounds
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func startSession() async {
        guard game.roundRobinStatus == .waiting else { return }
        let playerIds = participants.map(\.userId)
        guard playerIds.count >= 2 else {
            errorMessage = "Need at least 2 players to start"
            return
        }

        let numRounds = game.numRounds ?? 5
        let isDoubles = game.gameFormat != .singles

        let schedule: [RoundRobinScheduler.RoundSchedule]
        if isDoubles {
            schedule = RoundRobinScheduler.generateDoublesSchedule(players: playerIds, numRounds: numRounds)
        } else {
            schedule = RoundRobinScheduler.generateSinglesSchedule(players: playerIds, numRounds: numRounds)
        }

        // Convert to payload
        var payloads: [GameService.RoundMatchPayload] = []
        for round in schedule {
            for match in round.matches {
                payloads.append(GameService.RoundMatchPayload(
                    round_number: round.roundNumber,
                    court_number: match.court,
                    team1_player1: match.team1[0],
                    team1_player2: match.team1.count > 1 ? match.team1[1] : nil,
                    team2_player1: match.team2[0],
                    team2_player2: match.team2.count > 1 ? match.team2[1] : nil,
                    bye_players: round.byes
                ))
            }
        }

        do {
            try await GameService.startRoundRobin(gameId: game.id, rounds: payloads)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submitScore(roundId: UUID, team1Score: Int, team2Score: Int) async {
        do {
            try await GameService.submitRoundScore(roundId: roundId, team1Score: team1Score, team2Score: team2Score)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func playerName(for id: UUID) -> String {
        if let p = participants.first(where: { $0.userId == id }) {
            return p.displayName
        }
        return "Player"
    }
}
