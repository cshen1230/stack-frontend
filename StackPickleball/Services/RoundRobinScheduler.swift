import Foundation

enum RoundRobinScheduler {

    struct MatchSlot {
        let court: Int
        let team1: [UUID]
        let team2: [UUID]
    }

    struct RoundSchedule {
        let roundNumber: Int
        let matches: [MatchSlot]
        let byes: [UUID]
    }

    // MARK: - Singles Schedule (Circle Method)

    static func generateSinglesSchedule(players: [UUID], numRounds: Int) -> [RoundSchedule] {
        var list = players.shuffled()
        let hasBye = list.count % 2 != 0
        let byeId = UUID() // phantom player
        if hasBye { list.append(byeId) }
        let n = list.count

        var rounds: [RoundSchedule] = []
        for r in 0..<numRounds {
            let rotation = r % (n - 1)
            // Build rotated array: fix index 0, rotate rest
            var rotated = [list[0]]
            for i in 1..<n {
                let idx = ((i - 1 + rotation) % (n - 1)) + 1
                rotated.append(list[idx])
            }

            var matches: [MatchSlot] = []
            var byes: [UUID] = []
            var court = 1
            for i in 0..<(n / 2) {
                let p1 = rotated[i]
                let p2 = rotated[n - 1 - i]
                if hasBye && (p1 == byeId || p2 == byeId) {
                    let real = p1 == byeId ? p2 : p1
                    byes.append(real)
                } else {
                    matches.append(MatchSlot(court: court, team1: [p1], team2: [p2]))
                    court += 1
                }
            }
            rounds.append(RoundSchedule(roundNumber: r + 1, matches: matches, byes: byes))
        }
        return rounds
    }

    // MARK: - Doubles Schedule (Circle Method for Unique Partnerships)

    static func generateDoublesSchedule(players: [UUID], numRounds: Int) -> [RoundSchedule] {
        var list = players.shuffled()
        let hasBye = list.count % 2 != 0
        let byeId = UUID() // phantom player for odd count
        if hasBye { list.append(byeId) }
        let n = list.count
        let maxUniqueRounds = n - 1

        var rounds: [RoundSchedule] = []

        for r in 0..<numRounds {
            let rotation = r % maxUniqueRounds

            // Circle method: fix player[0], rotate players[1..n-1]
            var rotated = [list[0]]
            for i in 1..<n {
                let idx = ((i - 1 + rotation) % (n - 1)) + 1
                rotated.append(list[idx])
            }

            // Generate partnerships by matching i with n-1-i
            // This guarantees every pair appears exactly once across n-1 rounds
            var partnerships: [(UUID, UUID)] = []
            var byes: [UUID] = []
            for i in 0..<(n / 2) {
                let p1 = rotated[i]
                let p2 = rotated[n - 1 - i]
                if hasBye && (p1 == byeId || p2 == byeId) {
                    let real = p1 == byeId ? p2 : p1
                    byes.append(real)
                } else {
                    partnerships.append((p1, p2))
                }
            }

            // Group partnerships into courts: each court is partnership vs partnership
            var matches: [MatchSlot] = []
            var court = 1
            var idx = 0
            while idx + 1 < partnerships.count {
                let team1 = [partnerships[idx].0, partnerships[idx].1]
                let team2 = [partnerships[idx + 1].0, partnerships[idx + 1].1]
                matches.append(MatchSlot(court: court, team1: team1, team2: team2))
                court += 1
                idx += 2
            }
            // Odd number of partnerships — last pair sits out
            if idx < partnerships.count {
                byes.append(partnerships[idx].0)
                byes.append(partnerships[idx].1)
            }

            rounds.append(RoundSchedule(roundNumber: r + 1, matches: matches, byes: byes))
        }
        return rounds
    }

    // MARK: - Leaderboard

    struct LeaderboardEntry: Identifiable {
        let playerId: UUID
        var wins: Int = 0
        var losses: Int = 0
        var totalPoints: Int = 0
        var pointDifferential: Int = 0
        var gamesPlayed: Int = 0

        var id: UUID { playerId }

        var avgPointDifferential: Double {
            gamesPlayed > 0 ? Double(pointDifferential) / Double(gamesPlayed) : 0
        }
    }

    static func computeLeaderboard(rounds: [RoundRobinRound]) -> [LeaderboardEntry] {
        var entries: [UUID: LeaderboardEntry] = [:]

        for round in rounds {
            guard let s1 = round.team1Score, let s2 = round.team2Score else { continue }
            let team1Won = s1 > s2
            let diff = s1 - s2

            let team1 = [round.team1Player1] + (round.team1Player2.map { [$0] } ?? [])
            let team2 = [round.team2Player1] + (round.team2Player2.map { [$0] } ?? [])

            for p in team1 {
                var e = entries[p] ?? LeaderboardEntry(playerId: p)
                if team1Won { e.wins += 1 } else { e.losses += 1 }
                e.totalPoints += s1
                e.pointDifferential += diff
                e.gamesPlayed += 1
                entries[p] = e
            }
            for p in team2 {
                var e = entries[p] ?? LeaderboardEntry(playerId: p)
                if team1Won { e.losses += 1 } else { e.wins += 1 }
                e.totalPoints += s2
                e.pointDifferential -= diff
                e.gamesPlayed += 1
                entries[p] = e
            }
        }

        return entries.values.sorted {
            if $0.wins != $1.wins { return $0.wins > $1.wins }
            return $0.pointDifferential > $1.pointDifferential
        }
    }
}
