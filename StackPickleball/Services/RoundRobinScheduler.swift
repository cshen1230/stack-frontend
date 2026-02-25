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

    // MARK: - Doubles Schedule (Circle Method + Opponent-Balanced Court Assignment)

    static func generateDoublesSchedule(players: [UUID], numRounds: Int) -> [RoundSchedule] {
        var list = players.shuffled()
        let hasBye = list.count % 2 != 0
        let byeId = UUID() // phantom player for odd count
        if hasBye { list.append(byeId) }
        let n = list.count
        let maxUniqueRounds = n - 1

        // Track opponent counts across all rounds for balancing
        var opponentCounts: [UUID: [UUID: Int]] = [:]

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

            // Optimally assign partnerships to courts to balance opponents
            let bestSplit = bestCourtAssignment(partnerships: partnerships, opponentCounts: opponentCounts)

            var matches: [MatchSlot] = []
            var court = 1
            for (team1Pair, team2Pair) in bestSplit.matches {
                let team1 = [team1Pair.0, team1Pair.1]
                let team2 = [team2Pair.0, team2Pair.1]
                matches.append(MatchSlot(court: court, team1: team1, team2: team2))
                court += 1
            }
            // Odd number of partnerships — last pair sits out
            for byePair in bestSplit.byes {
                byes.append(byePair.0)
                byes.append(byePair.1)
            }

            // Update opponent counts for this round's matches
            for match in matches {
                for p1 in match.team1 {
                    for p2 in match.team2 {
                        opponentCounts[p1, default: [:]][p2, default: 0] += 1
                        opponentCounts[p2, default: [:]][p1, default: 0] += 1
                    }
                }
            }

            rounds.append(RoundSchedule(roundNumber: r + 1, matches: matches, byes: byes))
        }
        return rounds
    }

    // MARK: - Court Assignment Optimizer

    private struct CourtSplit {
        let matches: [((UUID, UUID), (UUID, UUID))]
        let byes: [(UUID, UUID)]
    }

    /// Try all ways to pair partnerships into courts and pick the one
    /// that minimizes the maximum opponent-pair count.
    private static func bestCourtAssignment(
        partnerships: [(UUID, UUID)],
        opponentCounts: [UUID: [UUID: Int]]
    ) -> CourtSplit {
        let allSplits = generateAllCourtSplits(partnerships: partnerships)
        guard !allSplits.isEmpty else {
            return CourtSplit(matches: [], byes: partnerships)
        }

        var bestSplit = allSplits[0]
        var bestScore = evaluateSplit(allSplits[0], opponentCounts: opponentCounts)

        for split in allSplits.dropFirst() {
            let score = evaluateSplit(split, opponentCounts: opponentCounts)
            if score < bestScore {
                bestScore = score
                bestSplit = split
            }
        }

        return bestSplit
    }

    /// Score a split: lower is better. Primary: minimize max opponent count.
    /// Secondary: minimize sum of squared opponent counts (spread evenly).
    private static func evaluateSplit(
        _ split: CourtSplit,
        opponentCounts: [UUID: [UUID: Int]]
    ) -> (Int, Int) {
        var maxCount = 0
        var sumSquared = 0

        for (team1, team2) in split.matches {
            let team1Players = [team1.0, team1.1]
            let team2Players = [team2.0, team2.1]
            for p1 in team1Players {
                for p2 in team2Players {
                    let current = opponentCounts[p1]?[p2] ?? 0
                    let newCount = current + 1
                    maxCount = max(maxCount, newCount)
                    sumSquared += newCount * newCount
                }
            }
        }

        return (maxCount, sumSquared)
    }

    /// Generate all ways to split an array of partnerships into pairs (courts).
    /// For N partnerships, this produces all perfect matchings of the partnerships.
    /// E.g. for 4 partnerships [A,B,C,D]: (A vs B, C vs D), (A vs C, B vs D), (A vs D, B vs C)
    private static func generateAllCourtSplits(
        partnerships: [(UUID, UUID)]
    ) -> [CourtSplit] {
        guard partnerships.count >= 2 else {
            // 0 or 1 partnerships — all sit out
            return [CourtSplit(matches: [], byes: partnerships)]
        }

        var results: [CourtSplit] = []
        generateSplitsRecursive(
            remaining: partnerships,
            currentMatches: [],
            results: &results
        )
        return results
    }

    /// Recursively generate all perfect matchings of partnerships into courts.
    /// Fix the first partnership, try pairing it with each other, recurse on the rest.
    private static func generateSplitsRecursive(
        remaining: [(UUID, UUID)],
        currentMatches: [((UUID, UUID), (UUID, UUID))],
        results: inout [CourtSplit]
    ) {
        if remaining.count < 2 {
            // 0 remaining = perfect split, 1 remaining = that pair gets a bye
            results.append(CourtSplit(matches: currentMatches, byes: remaining))
            return
        }

        let first = remaining[0]
        let rest = Array(remaining.dropFirst())

        for i in 0..<rest.count {
            let partner = rest[i]
            var nextRemaining = rest
            nextRemaining.remove(at: i)

            generateSplitsRecursive(
                remaining: nextRemaining,
                currentMatches: currentMatches + [(first, partner)],
                results: &results
            )
        }
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
