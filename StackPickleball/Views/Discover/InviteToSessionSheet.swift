import SwiftUI

struct InviteToSessionSheet: View {
    let player: AvailablePlayer
    var onInvite: ((Game) async -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var sessions: [Game] = []
    @State private var isLoading = true
    @State private var invitedGameIds: Set<UUID> = []
    @State private var invitingId: UUID?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.stackGreen)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if sessions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundColor(.stackSecondaryText)
                        Text("No Available Sessions")
                            .font(.system(size: 18, weight: .bold))
                        Text("All your sessions are full, or you have no active sessions.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(sessions) { game in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(game.sessionName ?? game.creatorDisplayName + "'s Session")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)

                                HStack(spacing: 6) {
                                    Text(game.gameFormat.displayName)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.stackGreen)

                                    Text("\u{00B7}")
                                        .fontWeight(.bold)
                                        .foregroundColor(.stackSecondaryText)

                                    Text("\(game.spotsRemaining) spot\(game.spotsRemaining == 1 ? "" : "s") left")
                                        .font(.system(size: 12))
                                        .foregroundColor(.stackSecondaryText)
                                }

                                Text(game.gameDatetime, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                                    .font(.system(size: 12))
                                    .foregroundColor(.stackTimestamp)
                            }

                            Spacer()

                            if invitedGameIds.contains(game.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.stackGreen)
                            } else if invitingId == game.id {
                                ProgressView()
                                    .tint(.stackGreen)
                            } else {
                                Button {
                                    Task { await invite(to: game) }
                                } label: {
                                    Text("Invite")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.stackGreen)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(Color.stackBackground)
            .navigationTitle("Invite \(player.firstName ?? player.displayName)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadSessions()
            }
            .errorAlert($errorMessage)
        }
    }

    private func loadSessions() async {
        guard let userId = appState.currentUser?.id else {
            isLoading = false
            return
        }
        do {
            let all = try await MessageService.myActiveSessions(userId: userId)
            sessions = all.filter { $0.spotsRemaining > 0 }
        } catch where error.isCancellation {
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func invite(to game: Game) async {
        invitingId = game.id
        await onInvite?(game)
        invitedGameIds.insert(game.id)
        invitingId = nil
    }
}
