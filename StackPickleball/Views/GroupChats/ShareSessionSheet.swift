import SwiftUI

struct ShareSessionSheet: View {
    let groupChatId: UUID
    var onShared: (() async -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var sessions: [Game] = []
    @State private var isLoading = true
    @State private var sharingId: UUID?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if sessions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundColor(.stackSecondaryText)
                        Text("No active sessions to share")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(sessions) { game in
                        Button {
                            Task { await shareSession(game) }
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(game.sessionName ?? game.creatorDisplayName)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)

                                    HStack(spacing: 6) {
                                        Text(game.gameFormat.displayName)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.stackGreen)

                                        Text("·")
                                            .fontWeight(.bold)
                                            .foregroundColor(.stackTimestamp)

                                        Text(game.gameDatetime, format: .dateTime.month(.abbreviated).day().hour().minute())
                                            .font(.system(size: 12))
                                            .foregroundColor(.stackTimestamp)
                                    }

                                    if let location = game.locationName {
                                        HStack(spacing: 3) {
                                            Image(systemName: "mappin")
                                                .font(.system(size: 10))
                                            Text(location)
                                                .font(.system(size: 11))
                                        }
                                        .foregroundColor(.stackTimestamp)
                                    }
                                }

                                Spacer()

                                if sharingId == game.id {
                                    ProgressView()
                                } else {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.stackGreen)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .disabled(sharingId != nil)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(Color.stackBackground)
            .navigationTitle("Share Session")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
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
            sessions = try await MessageService.myActiveSessions(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func shareSession(_ game: Game) async {
        sharingId = game.id
        let content = "\(game.sessionName ?? game.creatorDisplayName) — \(game.gameFormat.displayName)"
        do {
            try await GroupChatService.shareSession(
                groupChatId: groupChatId,
                gameId: game.id,
                content: content
            )
            await onShared?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        sharingId = nil
    }
}
