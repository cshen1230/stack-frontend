import SwiftUI

struct GameDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let game: Game
    let isHost: Bool

    @State private var participants: [ParticipantWithProfile] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                // Game info section
                Section("Game Info") {
                    LabeledContent("Format", value: game.gameFormat.displayName)
                    LabeledContent("Date") {
                        Text(game.gameDatetime, style: .date)
                    }
                    LabeledContent("Time") {
                        Text(game.gameDatetime, style: .time)
                    }
                    if let location = game.locationName {
                        LabeledContent("Location", value: location)
                    }
                    if let min = game.skillLevelMin, let max = game.skillLevelMax {
                        LabeledContent("DUPR Range", value: "\(String(format: "%.1f", min)) - \(String(format: "%.1f", max))")
                    }
                    LabeledContent("Spots", value: "\(game.spotsFilled)/\(game.spotsAvailable)")
                    if let desc = game.description, !desc.isEmpty {
                        Text(desc)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // Participants section
                Section("Players (\(participants.count))") {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if participants.isEmpty {
                        Text("No participants yet")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(participants) { participant in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(participant.displayName)
                                            .font(.system(size: 15, weight: .medium))

                                        if participant.userId == game.creatorId {
                                            HStack(spacing: 2) {
                                                Image(systemName: "crown.fill")
                                                    .font(.system(size: 10))
                                                Text("Host")
                                                    .font(.system(size: 11, weight: .semibold))
                                            }
                                            .foregroundColor(.orange)
                                        }
                                    }

                                    HStack(spacing: 4) {
                                        Text("@\(participant.users.username)")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)

                                        if let rating = participant.users.duprRating {
                                            Text("\u{2022}")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                            Text("DUPR \(String(format: "%.1f", rating))")
                                                .font(.system(size: 13))
                                                .foregroundColor(.stackGreen)
                                        }
                                    }
                                }

                                Spacer()
                            }
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(game.creatorDisplayName + "'s Game")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadParticipants()
            }
        }
    }

    private func loadParticipants() async {
        isLoading = true
        do {
            participants = try await GameService.gameParticipants(gameId: game.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
