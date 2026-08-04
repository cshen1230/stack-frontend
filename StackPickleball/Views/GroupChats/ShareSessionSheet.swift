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
                    ScrollView {
                        SkeletonList(count: 3) { SkeletonCard() }
                            .padding(AppConstants.screenPadding)
                    }
                } else if sessions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundColor(.stackSecondaryText)
                        Text("No active sessions to share")
                            .font(AppFonts.body())
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
                                        .font(AppFonts.body())
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)

                                    HStack(spacing: 6) {
                                        Text(game.gameFormat.displayName)
                                            .font(AppFonts.caption())
                                            .fontWeight(.medium)
                                            .foregroundColor(.stackGreen)

                                        Text("·")
                                            .fontWeight(.bold)
                                            .foregroundColor(.stackTimestamp)

                                        Text(game.gameDatetime, format: .dateTime.month(.abbreviated).day().hour().minute())
                                            .font(AppFonts.caption())
                                            .foregroundColor(.stackTimestamp)
                                    }

                                    if let location = game.locationName {
                                        HStack(spacing: 3) {
                                            Image(systemName: "mappin")
                                                .font(.system(size: 10))
                                            Text(location)
                                                .font(AppFonts.caption2())
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
            errorMessage = error.userFacingMessage
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
            errorMessage = error.userFacingMessage
        }
        sharingId = nil
    }
}
