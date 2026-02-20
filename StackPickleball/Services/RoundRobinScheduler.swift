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

    // MARK: - Doubles Schedule (Rotation + Partner Cycling)

    static func generateDoublesSchedule(players: [UUID], numRounds: Int) -> [RoundSchedule] {
        let shuffled = players.shuffled()
        let n = shuffled.count
        let onCourt = (n / 4) * 4
        let numByes = n - onCourt

        var rounds: [RoundSchedule] = []

        for r in 0..<numRounds {
            // Determine who sits out this round (rotate fairly)
            var byes: [UUID] = []
            var active: [UUID]
            if numByes > 0 {
                let startBye = (r * numByes) % n
                for b in 0..<numByes {
                    byes.append(shuffled[(startBye + b) % n])
                }
                active = shuffled.filter { !byes.contains($0) }
            } else {
                active = shuffled
            }

            // Rotate active players for partner diversity
            let shift = r % active.count
            let rotated = Array(active[shift...]) + Array(active[..<shift])

            var matches: [MatchSlot] = []
            let numCourts = rotated.count / 4

            for c in 0..<numCourts {
                let base = c * 4
                let team1: [UUID]
                let team2: [UUID]
                // Alternate partner pairing pattern for balance
                switch r % 3 {
                case 0:
                    team1 = [rotated[base], rotated[base + 1]]
                    team2 = [rotated[base + 2], rotated[base + 3]]
                case 1:
                    team1 = [rotated[base], rotated[base + 2]]
                    team2 = [rotated[base + 1], rotated[base + 3]]
                default:
                    team1 = [rotated[base], rotated[base + 3]]
                    team2 = [rotated[base + 1], rotated[base + 2]]
                }
                matches.append(MatchSlot(court: c + 1, team1: team1, team2: team2))
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
