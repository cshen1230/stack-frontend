import SwiftUI

struct RoundRobinDetailView: View {
    let game: Game
    let isHost: Bool

    @Environment(AppState.self) private var appState
    @State private var viewModel: RoundRobinViewModel
    @State private var selectedTab = 0
    @State private var scoreRound: RoundRobinRound?

    init(game: Game, isHost: Bool) {
        self.game = game
        self.isHost = isHost
        self._viewModel = State(initialValue: RoundRobinViewModel(game: game))
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if game.roundRobinStatus == .waiting || viewModel.rounds.isEmpty {
                waitingView
            } else {
                // Segmented tabs
                Picker("Tab", selection: $selectedTab) {
                    Text("Schedule").tag(0)
                    Text("Leaderboard").tag(1)
                    Text("Players").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                switch selectedTab {
                case 0: scheduleTab
                case 1: leaderboardTab
                default: playersTab
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.stackBackground)
        .navigationTitle(game.sessionName ?? "Round Robin")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.loadData()
        }
        .sheet(item: $scoreRound) { round in
            ScoreEntrySheet(round: round, viewModel: viewModel) {
                scoreRound = nil
            }
        }
        .errorAlert($viewModel.errorMessage)
    }

    // MARK: - Waiting View

    private var waitingView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Game info
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(game.gameFormat.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.stackGreen)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.stackBadgeBg)
                            .cornerRadius(8)

                        Text("Round Robin")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.stackGreen)
                            .cornerRadius(8)
                    }

                    if let numRounds = game.numRounds {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 13))
                                .foregroundColor(.stackSecondaryText)
                            Text("\(numRounds) rounds")
                                .font(.system(size: 14))
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "person.2")
                            .font(.system(size: 13))
                            .foregroundColor(.stackSecondaryText)
                        Text("\(viewModel.participants.count)/\(game.spotsAvailable) players joined")
                            .font(.system(size: 14))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.stackCardWhite)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black, lineWidth: 1))
                .padding(.horizontal, 16)

                // Player list
                VStack(alignment: .leading, spacing: 8) {
                    Text("Players (\(viewModel.participants.count))")
                        .font(.system(size: 18, weight: .bold))
                        .padding(.horizontal, 16)

                    ForEach(viewModel.participants) { p in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                )
                            Text(p.displayName)
                                .font(.system(size: 15, weight: .medium))
                            if p.userId == game.creatorId {
                                Text("Host")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.orange)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                    }
                }

                // Start button (host only)
                if isHost && viewModel.participants.count >= 2 {
                    Button {
                        Task { await viewModel.startSession() }
                    } label: {
                        Text("Start Round Robin")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.stackGreen)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 24)
            }
            .padding(.top, 12)
        }
    }

    // MARK: - Schedule Tab

    private var scheduleTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.roundGroups, id: \.number) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Round \(group.number)")
                            .font(.system(size: 16, weight: .bold))
                            .padding(.horizontal, 16)

                        if !group.byes.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "pause.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Text("Sitting out: \(group.byes.map { viewModel.playerName(for: $0) }.joined(separator: ", "))")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                        }

                        ForEach(group.matches) { match in
                            MatchCard(match: match, viewModel: viewModel) {
                                scoreRound = match
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Leaderboard Tab

    private var leaderboardTab: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(viewModel.leaderboard.enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: 12) {
                        // Rank
                        Text("#\(index + 1)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(index < 3 ? .stackGreen : .secondary)
                            .frame(width: 36)

                        Text(viewModel.playerName(for: entry.playerId))
                            .font(.system(size: 15, weight: .medium))

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(entry.wins)W - \(entry.losses)L")
                                .font(.system(size: 14, weight: .semibold))
                            Text("\(entry.avgPointDifferential >= 0 ? "+" : "")\(String(format: "%.1f", entry.avgPointDifferential)) avg diff")
                                .font(.system(size: 12))
                                .foregroundColor(entry.avgPointDifferential >= 0 ? .stackGreen : .secondary)
                        }
                    }
                    .padding(12)
                    .background(Color.stackCardWhite)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.08), lineWidth: 1))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }

    // MARK: - Players Tab

    private var playersTab: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.participants) { p in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            )

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(p.displayName)
                                    .font(.system(size: 16, weight: .semibold))
                                if p.userId == game.creatorId {
                                    HStack(spacing: 2) {
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 10))
                                        Text("Host")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .foregroundColor(.orange)
                                }
                            }
                            if let rating = p.users.duprRating {
                                Text("DUPR \(String(format: "%.1f", rating))")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.stackGreen)
                            }
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.stackCardWhite)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.08), lineWidth: 1))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }
}

// MARK: - Match Card

private struct MatchCard: View {
    let match: RoundRobinRound
    let viewModel: RoundRobinViewModel
    let onTap: () -> Void

    private var team1Names: String {
        let names = [viewModel.playerName(for: match.team1Player1)]
            + (match.team1Player2.map { [viewModel.playerName(for: $0)] } ?? [])
        return names.joined(separator: " & ")
    }

    private var team2Names: String {
        let names = [viewModel.playerName(for: match.team2Player1)]
            + (match.team2Player2.map { [viewModel.playerName(for: $0)] } ?? [])
        return names.joined(separator: " & ")
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                HStack {
                    Text(team1Names)
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity)
                    Text("vs")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(team2Names)
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity)
                }

                if match.hasScore {
                    HStack {
                        Text("\(match.team1Score ?? 0)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor((match.team1Score ?? 0) > (match.team2Score ?? 0) ? .stackGreen : .primary)
                            .frame(maxWidth: .infinity)
                        Text("–")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.secondary)
                        Text("\(match.team2Score ?? 0)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor((match.team2Score ?? 0) > (match.team1Score ?? 0) ? .stackGreen : .primary)
                            .frame(maxWidth: .infinity)
                    }
                    Text("Tap to edit")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    Text("Tap to enter score")
                        .font(.system(size: 12))
                        .foregroundColor(.stackGreen)
                }
            }
            .padding(12)
            .background(match.hasScore ? Color.stackBadgeBg : Color.stackCardWhite)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(match.hasScore ? Color.stackGreen.opacity(0.3) : Color.black.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
