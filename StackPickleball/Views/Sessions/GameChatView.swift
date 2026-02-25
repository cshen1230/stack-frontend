import SwiftUI

struct GameChatView: View {
    let game: Game
    let currentUserId: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var messages: [GameMessage] = []
    @State private var messageText = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var hasMoreMessages = false
    @State private var showingSessionSettings = false
    @State private var hostId: UUID
    @FocusState private var isInputFocused: Bool

    init(game: Game, currentUserId: UUID) {
        self.game = game
        self.currentUserId = currentUserId
        self._hostId = State(initialValue: game.creatorId)
    }

    private var isHost: Bool { hostId == currentUserId }

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }

                Spacer()

                Text(game.sessionName ?? "Chat")
                    .font(.system(size: 16, weight: .semibold))

                Spacer()

                Button {
                    showingSessionSettings = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 8)
            .background(Color.stackBackground)

            // Messages area
            ScrollViewReader { proxy in
                ScrollView {
                    if isLoading {
                        ProgressView()
                            .tint(.stackGreen)
                            .padding(.top, 80)
                    } else if messages.isEmpty {
                        VStack(spacing: 16) {
                            Spacer().frame(height: 80)

                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 44))
                                .foregroundColor(.stackGreen.opacity(0.4))

                            Text("Start the conversation")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)

                            Text("Say hello to your group!")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 2) {
                            if hasMoreMessages {
                                Button {
                                    Task { await loadMoreMessages() }
                                } label: {
                                    Text("Load earlier messages")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.stackGreen)
                                        .padding(.vertical, 8)
                                }
                                .padding(.top, 4)
                            }
                            ForEach(messages) { message in
                                MessageBubble(
                                    message: message,
                                    isFromCurrentUser: message.userId == currentUserId
                                )
                                .id(message.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    }
                }
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onTapGesture {
                    isInputFocused = false
                }
            }

            // Input bar
            VStack(spacing: 0) {
                Divider()
                    .opacity(0.4)

                HStack(alignment: .bottom, spacing: 10) {
                    TextField("Message", text: $messageText, axis: .vertical)
                        .font(.system(size: 16))
                        .lineLimit(1...5)
                        .focused($isInputFocused)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 22)
                                .fill(Color(.systemGray6))
                        )

                    Button {
                        Task { await sendMessage() }
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 34, height: 34)
                            .background(
                                Circle()
                                    .fill(canSend ? Color.stackGreen : Color(.systemGray4))
                            )
                    }
                    .disabled(!canSend)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(Color.stackBackground)
        }
        .background(Color.stackBackground)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .task {
            // Fetch the current host from the server so we have the latest value
            async let fetchHost: Void = {
                if let creatorId = try? await GameService.gameCreatorId(gameId: game.id) {
                    hostId = creatorId
                }
            }()
            async let fetchMessages: Void = loadMessages()
            _ = await (fetchHost, fetchMessages)
        }
        .refreshable {
            await loadMessages()
        }
        .sheet(isPresented: $showingSessionSettings) {
            SessionSettingsSheet(
                game: game,
                currentUserId: currentUserId,
                currentHostId: $hostId,
                onLeave: {
                    dismiss()
                },
                onDelete: {
                    dismiss()
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private let pageSize = 50

    private func loadMessages() async {
        do {
            let fetched = try await MessageService.messages(gameId: game.id, limit: pageSize)
            messages = fetched
            hasMoreMessages = fetched.count >= pageSize
        } catch where error.isCancellation {
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func loadMoreMessages() async {
        guard let oldest = messages.first else { return }
        do {
            let older = try await MessageService.messagesBefore(
                gameId: game.id, before: oldest.createdAt, limit: pageSize
            )
            hasMoreMessages = older.count >= pageSize
            messages = older + messages
        } catch where error.isCancellation {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sendMessage() async {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        messageText = ""
        do {
            try await MessageService.sendMessage(gameId: game.id, content: text)
            // Fetch only messages newer than what we have
            let latest = messages.last?.createdAt ?? Date.distantPast
            let newMessages = try await MessageService.messagesAfter(
                gameId: game.id, after: latest
            )
            if !newMessages.isEmpty {
                messages.append(contentsOf: newMessages)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Session Settings Sheet

private struct SessionSettingsSheet: View {
    let game: Game
    let currentUserId: UUID
    @Binding var currentHostId: UUID
    let onLeave: () -> Void
    let onDelete: () -> Void

    private var isHost: Bool { currentHostId == currentUserId }

    @Environment(\.dismiss) private var dismiss
    @State private var participants: [ParticipantWithProfile] = []
    @State private var isLoadingParticipants = true
    @State private var showingDeleteConfirm = false
    @State private var showingLeaveConfirm = false
    @State private var showingKickConfirm: ParticipantWithProfile?
    @State private var showingTransferConfirm: ParticipantWithProfile?
    @State private var errorMessage: String?
    @State private var isProcessing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Session info
                    VStack(spacing: 6) {
                        Text(game.sessionName ?? game.creatorDisplayName)
                            .font(.system(size: 20, weight: .bold))

                        HStack(spacing: 4) {
                            if let location = game.locationName {
                                Text(location)
                                Text("·").fontWeight(.bold)
                            }
                            Text(game.gameDatetime, format: .dateTime.month(.abbreviated).day().hour().minute())
                            Text("·").fontWeight(.bold)
                            Text(game.gameFormat.displayName)
                        }
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    // Players section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Players (\(participants.count))")
                            .font(.system(size: 16, weight: .bold))
                            .padding(.horizontal, 4)

                        if isLoadingParticipants {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        } else {
                            ForEach(participants) { participant in
                                HStack(spacing: 12) {
                                    // Avatar
                                    if let avatarUrl = participant.users.avatarUrl, let url = URL(string: avatarUrl) {
                                        AsyncImage(url: url) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            participantPlaceholder
                                        }
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                    } else {
                                        participantPlaceholder
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(participant.displayName)
                                                .font(.system(size: 15, weight: .medium))

                                            if participant.userId == currentHostId {
                                                HStack(spacing: 2) {
                                                    Image(systemName: "crown.fill")
                                                        .font(.system(size: 9))
                                                    Text("Host")
                                                        .font(.system(size: 10, weight: .semibold))
                                                }
                                                .foregroundColor(.orange)
                                            }
                                        }

                                        if let rating = participant.users.duprRating {
                                            Text("DUPR \(String(format: "%.1f", rating))")
                                                .font(.system(size: 12))
                                                .foregroundColor(.stackGreen)
                                        }
                                    }

                                    Spacer()

                                    // Host actions on other players
                                    if isHost && participant.userId != currentUserId {
                                        Menu {
                                            Button {
                                                showingTransferConfirm = participant
                                            } label: {
                                                Label("Transfer Host", systemImage: "crown")
                                            }

                                            Button(role: .destructive) {
                                                showingKickConfirm = participant
                                            } label: {
                                                Label("Remove", systemImage: "person.badge.minus")
                                            }
                                        } label: {
                                            Image(systemName: "ellipsis")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.secondary)
                                                .frame(width: 32, height: 32)
                                        }
                                    }
                                }
                                .padding(10)
                                .background(Color.stackCardWhite)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.stackBorder, lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // Actions
                    VStack(spacing: 10) {
                        if !isHost {
                            Button {
                                showingLeaveConfirm = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.system(size: 15))
                                    Text("Leave Session")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .disabled(isProcessing)
                        } else {
                            Button {
                                showingDeleteConfirm = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 15))
                                    Text("Delete Session")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .disabled(isProcessing)
                        }
                    }
                    .padding(.horizontal, 16)

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color.stackBackground)
            .navigationTitle("Session Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadParticipants()
            }
            .alert("Leave Session?", isPresented: $showingLeaveConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Leave", role: .destructive) {
                    Task { await leaveSession() }
                }
            } message: {
                Text("You will be removed from this session and its chat.")
            }
            .alert("Delete Session?", isPresented: $showingDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task { await deleteSession() }
                }
            } message: {
                Text("This will permanently delete the session for all participants.")
            }
            .alert(
                "Remove \(showingKickConfirm?.displayName ?? "")?",
                isPresented: Binding(
                    get: { showingKickConfirm != nil },
                    set: { if !$0 { showingKickConfirm = nil } }
                )
            ) {
                Button("Cancel", role: .cancel) { showingKickConfirm = nil }
                Button("Remove", role: .destructive) {
                    if let p = showingKickConfirm {
                        Task { await kickPlayer(p) }
                    }
                }
            } message: {
                Text("This player will be removed from the session.")
            }
            .alert(
                "Transfer host to \(showingTransferConfirm?.displayName ?? "")?",
                isPresented: Binding(
                    get: { showingTransferConfirm != nil },
                    set: { if !$0 { showingTransferConfirm = nil } }
                )
            ) {
                Button("Cancel", role: .cancel) { showingTransferConfirm = nil }
                Button("Transfer") {
                    if let p = showingTransferConfirm {
                        Task { await transferOwnership(p) }
                    }
                }
            } message: {
                Text("They will become the host and you will become a regular participant.")
            }
        }
    }

    private var participantPlaceholder: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 40, height: 40)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            )
    }

    private func loadParticipants() async {
        do {
            participants = try await GameService.gameParticipants(gameId: game.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingParticipants = false
    }

    private func leaveSession() async {
        isProcessing = true
        do {
            try await GameService.cancelRsvp(gameId: game.id)
            dismiss()
            onLeave()
        } catch {
            errorMessage = error.localizedDescription
        }
        isProcessing = false
    }

    private func deleteSession() async {
        isProcessing = true
        do {
            try await GameService.deleteGame(gameId: game.id)
            dismiss()
            onDelete()
        } catch {
            errorMessage = error.localizedDescription
        }
        isProcessing = false
    }

    private func kickPlayer(_ participant: ParticipantWithProfile) async {
        isProcessing = true
        do {
            try await GameService.kickPlayer(gameId: game.id, userId: participant.userId)
            participants.removeAll { $0.id == participant.id }
        } catch {
            errorMessage = error.localizedDescription
        }
        showingKickConfirm = nil
        isProcessing = false
    }

    private func transferOwnership(_ participant: ParticipantWithProfile) async {
        isProcessing = true
        do {
            try await GameService.transferOwnership(gameId: game.id, newOwnerId: participant.userId)
            currentHostId = participant.userId
        } catch {
            errorMessage = error.localizedDescription
        }
        showingTransferConfirm = nil
        isProcessing = false
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: GameMessage
    let isFromCurrentUser: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isFromCurrentUser {
                Spacer(minLength: 48)
            } else {
                // Avatar circle with initial
                Text(String(message.users.firstName.prefix(1)))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.stackGreen.opacity(0.7)))
                    .padding(.top, 2)
            }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isFromCurrentUser {
                    Text(message.senderDisplayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.stackSecondaryText)
                }

                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isFromCurrentUser ? Color.stackGreen : Color(.systemGray6))
                    .cornerRadius(20)

                Text(message.createdAt, format: .dateTime.hour().minute())
                    .font(.system(size: 11))
                    .foregroundColor(.stackTimestamp)
            }

            if !isFromCurrentUser {
                Spacer(minLength: 48)
            }
        }
        .padding(.vertical, 4)
    }
}
