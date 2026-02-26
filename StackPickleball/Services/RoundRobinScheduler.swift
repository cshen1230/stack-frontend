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

    // MARK: - Doubles Schedule (Circle Method + Exhaustive Opponent Balancing)

    static func generateDoublesSchedule(players: [UUID], numRounds: Int) -> [RoundSchedule] {
        var list = players.shuffled()
        let hasBye = list.count % 2 != 0
        let byeId = UUID()
        if hasBye { list.append(byeId) }
        let n = list.count
        let maxUniqueRounds = n - 1

        // Step 1: Generate all rounds' partnerships via circle method (1-factorization)
        var allRoundPartnerships: [[(UUID, UUID)]] = []
        var allRoundByes: [[UUID]] = []

        for r in 0..<numRounds {
            let rotation = r % maxUniqueRounds
            var rotated = [list[0]]
            for i in 1..<n {
                let idx = ((i - 1 + rotation) % (n - 1)) + 1
                rotated.append(list[idx])
            }

            var partnerships: [(UUID, UUID)] = []
            var byes: [UUID] = []
            for i in 0..<(n / 2) {
                let p1 = rotated[i]
                let p2 = rotated[n - 1 - i]
                if hasBye && (p1 == byeId || p2 == byeId) {
                    byes.append(p1 == byeId ? p2 : p1)
                } else {
                    partnerships.append((p1, p2))
                }
            }
            allRoundPartnerships.append(partnerships)
            allRoundByes.append(byes)
        }

        // Step 2: For each round, compute all possible court splits
        let allRoundSplits = allRoundPartnerships.map { courtSplitsForRound($0) }

        // Step 3: Find optimal combination across all rounds
        let bestChoices: [Int]
        let totalCombinations = allRoundSplits.reduce(1) { $0 * max($1.count, 1) }

        if totalCombinations <= 200_000 {
            // Exhaustive search — enumerate all combinations
            bestChoices = exhaustiveSearch(
                allRoundSplits: allRoundSplits,
                allPlayers: list.filter { $0 != byeId }
            )
        } else {
            // Greedy fallback for large search spaces
            bestChoices = greedySearch(allRoundSplits: allRoundSplits)
        }

        // Step 4: Build final schedule from best choices
        var rounds: [RoundSchedule] = []
        for r in 0..<numRounds {
            let split = allRoundSplits[r][bestChoices[r]]
            var matches: [MatchSlot] = []
            var court = 1
            for (team1Pair, team2Pair) in split.matches {
                matches.append(MatchSlot(
                    court: court,
                    team1: [team1Pair.0, team1Pair.1],
                    team2: [team2Pair.0, team2Pair.1]
                ))
                court += 1
            }
            var byes = allRoundByes[r]
            for byePair in split.byes {
                byes.append(byePair.0)
                byes.append(byePair.1)
            }
            rounds.append(RoundSchedule(roundNumber: r + 1, matches: matches, byes: byes))
        }
        return rounds
    }

    // MARK: - Court Split Types

    private struct CourtSplit {
        let matches: [((UUID, UUID), (UUID, UUID))]
        let byes: [(UUID, UUID)]
    }

    // MARK: - Exhaustive Search

    /// Enumerate all combinations of court splits across all rounds.
    /// Score each by opponent balance: minimize (max - min), then std dev.
    private static func exhaustiveSearch(
        allRoundSplits: [[CourtSplit]],
        allPlayers: [UUID]
    ) -> [Int] {
        let numRounds = allRoundSplits.count
        let splitCounts = allRoundSplits.map { $0.count }
        let totalCombinations = splitCounts.reduce(1, *)

        var bestChoices = Array(repeating: 0, count: numRounds)
        var bestMaxMinDiff = Int.max
        var bestSumSquared = Int.max

        // Iterate through all combinations using mixed-radix counting
        var currentChoices = Array(repeating: 0, count: numRounds)

        for _ in 0..<totalCombinations {
            // Score this combination
            let (maxMinDiff, sumSquared) = scoreCombination(
                choices: currentChoices,
                allRoundSplits: allRoundSplits,
                allPlayers: allPlayers
            )

            if maxMinDiff < bestMaxMinDiff ||
                (maxMinDiff == bestMaxMinDiff && sumSquared < bestSumSquared) {
                bestMaxMinDiff = maxMinDiff
                bestSumSquared = sumSquared
                bestChoices = currentChoices
            }

            // Increment mixed-radix counter
            var carry = true
            for r in (0..<numRounds).reversed() {
                if carry {
                    currentChoices[r] += 1
                    if currentChoices[r] >= splitCounts[r] {
                        currentChoices[r] = 0
                    } else {
                        carry = false
                    }
                }
            }
        }

        return bestChoices
    }

    /// Score a full combination: build opponent matrix, return (max-min, sumSquared).
    private static func scoreCombination(
        choices: [Int],
        allRoundSplits: [[CourtSplit]],
        allPlayers: [UUID]
    ) -> (Int, Int) {
        var counts: [UUID: [UUID: Int]] = [:]

        for (r, choice) in choices.enumerated() {
            let split = allRoundSplits[r][choice]
            for (team1, team2) in split.matches {
                let t1 = [team1.0, team1.1]
                let t2 = [team2.0, team2.1]
                for p1 in t1 {
                    for p2 in t2 {
                        counts[p1, default: [:]][p2, default: 0] += 1
                        counts[p2, default: [:]][p1, default: 0] += 1
                    }
                }
            }
        }

        // Collect all pairwise opponent counts
        var allCounts: [Int] = []
        for i in 0..<allPlayers.count {
            for j in (i + 1)..<allPlayers.count {
                let c = counts[allPlayers[i]]?[allPlayers[j]] ?? 0
                allCounts.append(c)
            }
        }

        guard !allCounts.isEmpty else { return (0, 0) }

        let maxC = allCounts.max() ?? 0
        let minC = allCounts.min() ?? 0
        let sumSquared = allCounts.reduce(0) { $0 + $1 * $1 }

        return (maxC - minC, sumSquared)
    }

    // MARK: - Greedy Fallback

    /// Round-by-round greedy: pick split that minimizes max opponent count so far.
    private static func greedySearch(allRoundSplits: [[CourtSplit]]) -> [Int] {
        var opponentCounts: [UUID: [UUID: Int]] = [:]
        var choices: [Int] = []

        for splits in allRoundSplits {
            var bestIdx = 0
            var bestMax = Int.max
            var bestSumSq = Int.max

            for (idx, split) in splits.enumerated() {
                var tempMax = 0
                var tempSumSq = 0
                for (team1, team2) in split.matches {
                    for p1 in [team1.0, team1.1] {
                        for p2 in [team2.0, team2.1] {
                            let c = (opponentCounts[p1]?[p2] ?? 0) + 1
                            tempMax = max(tempMax, c)
                            tempSumSq += c * c
                        }
                    }
                }
                if tempMax < bestMax || (tempMax == bestMax && tempSumSq < bestSumSq) {
                    bestMax = tempMax
                    bestSumSq = tempSumSq
                    bestIdx = idx
                }
            }

            // Apply chosen split to running counts
            let chosen = splits[bestIdx]
            for (team1, team2) in chosen.matches {
                for p1 in [team1.0, team1.1] {
                    for p2 in [team2.0, team2.1] {
                        opponentCounts[p1, default: [:]][p2, default: 0] += 1
                        opponentCounts[p2, default: [:]][p1, default: 0] += 1
                    }
                }
            }
            choices.append(bestIdx)
        }
        return choices
    }

    // MARK: - Court Split Generation

    /// Generate all ways to split partnerships into courts (pairs of partnerships).
    private static func courtSplitsForRound(_ partnerships: [(UUID, UUID)]) -> [CourtSplit] {
        guard partnerships.count >= 2 else {
            return [CourtSplit(matches: [], byes: partnerships)]
        }
        var results: [CourtSplit] = []
        generateSplitsRecursive(remaining: partnerships, current: [], results: &results)
        return results
    }

    private static func generateSplitsRecursive(
        remaining: [(UUID, UUID)],
        current: [((UUID, UUID), (UUID, UUID))],
        results: inout [CourtSplit]
    ) {
        if remaining.count < 2 {
            results.append(CourtSplit(matches: current, byes: remaining))
            return
        }
        let first = remaining[0]
        let rest = Array(remaining.dropFirst())
        for i in 0..<rest.count {
            let opponent = rest[i]
            var next = rest
            next.remove(at: i)
            generateSplitsRecursive(remaining: next, current: current + [(first, opponent)], results: &results)
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
