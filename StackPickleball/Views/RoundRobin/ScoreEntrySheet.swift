import SwiftUI

struct ScoreEntrySheet: View {
    let round: RoundRobinRound
    let viewModel: RoundRobinViewModel
    let onDismiss: () -> Void

    @State private var team1ScoreText: String = ""
    @State private var team2ScoreText: String = ""
    @State private var isSubmitting = false

    private var team1Score: Int { Int(team1ScoreText) ?? 0 }
    private var team2Score: Int { Int(team2ScoreText) ?? 0 }

    private var team1Names: String {
        let names = [viewModel.playerName(for: round.team1Player1)]
            + (round.team1Player2.map { [viewModel.playerName(for: $0)] } ?? [])
        return names.joined(separator: " & ")
    }

    private var team2Names: String {
        let names = [viewModel.playerName(for: round.team2Player1)]
            + (round.team2Player2.map { [viewModel.playerName(for: $0)] } ?? [])
        return names.joined(separator: " & ")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Round \(round.roundNumber) · Court \(round.courtNumber)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.top, 16)

                // Team 1
                VStack(spacing: 8) {
                    Text(team1Names)
                        .font(.system(size: 16, weight: .semibold))
                    TextField("0", text: $team1ScoreText)
                        .font(.system(size: 36, weight: .bold))
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .frame(maxWidth: 120)
                }
                .padding(16)
                .background(Color.stackCardWhite)
                .cornerRadius(12)

                Text("vs")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.secondary)

                // Team 2
                VStack(spacing: 8) {
                    Text(team2Names)
                        .font(.system(size: 16, weight: .semibold))
                    TextField("0", text: $team2ScoreText)
                        .font(.system(size: 36, weight: .bold))
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .frame(maxWidth: 120)
                }
                .padding(16)
                .background(Color.stackCardWhite)
                .cornerRadius(12)

                Spacer()

                Button {
                    isSubmitting = true
                    Task {
                        await viewModel.submitScore(
                            roundId: round.id,
                            team1Score: team1Score,
                            team2Score: team2Score
                        )
                        isSubmitting = false
                        onDismiss()
                    }
                } label: {
                    Text("Submit Score")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.stackGreen)
                        .cornerRadius(14)
                }
                .disabled(isSubmitting || (team1ScoreText.isEmpty && team2ScoreText.isEmpty))
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 16)
            .background(Color.stackBackground)
            .navigationTitle("Enter Score")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
            }
        }
    }
}
