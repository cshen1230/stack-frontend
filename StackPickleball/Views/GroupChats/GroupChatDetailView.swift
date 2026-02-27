import SwiftUI

struct GroupChatDetailView: View {
    let groupChat: GroupChat
    let currentUserId: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var messages: [GroupChatMessage] = []
    @State private var messageText = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var hasMoreMessages = false
    @State private var showingCommunityInfo = false
    @State private var showingShareSession = false
    @FocusState private var isInputFocused: Bool

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

                Button {
                    showingCommunityInfo = true
                } label: {
                    VStack(spacing: 1) {
                        Text(groupChat.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        if let count = groupChat.memberCount {
                            Text("\(count) members")
                                .font(.system(size: 11))
                                .foregroundColor(.stackSecondaryText)
                        }
                    }
                }

                Spacer()

                Button {
                    showingCommunityInfo = true
                } label: {
                    Image(systemName: "info.circle")
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

                            Image(systemName: "bubble.left.and.text.bubble.right")
                                .font(.system(size: 44))
                                .foregroundColor(.stackGreen.opacity(0.4))

                            Text("Start the conversation")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)

                            Text("Say hello to your community!")
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
                                if message.messageType == .sessionShare, let gameId = message.sharedGameId {
                                    SessionShareBubble(
                                        message: message,
                                        gameId: gameId,
                                        isFromCurrentUser: message.userId == currentUserId
                                    )
                                    .id(message.id)
                                } else if message.messageType == .system {
                                    SystemMessageView(message: message)
                                        .id(message.id)
                                } else {
                                    GroupChatMessageBubble(
                                        message: message,
                                        isFromCurrentUser: message.userId == currentUserId
                                    )
                                    .id(message.id)
                                }
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
                    Button {
                        showingShareSession = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.stackGreen)
                    }
                    .padding(.bottom, 3)

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
            await loadMessages()
        }
        .refreshable {
            await loadMessages()
        }
        .fullScreenCover(isPresented: $showingCommunityInfo) {
            NavigationStack {
                CommunityInfoView(
                    groupChat: groupChat,
                    currentUserId: currentUserId,
                    onLeave: {
                        showingCommunityInfo = false
                        dismiss()
                    },
                    onDelete: {
                        showingCommunityInfo = false
                        dismiss()
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showingCommunityInfo = false
                        } label: {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSession) {
            ShareSessionSheet(groupChatId: groupChat.id) {
                await loadNewMessages()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private let pageSize = 50

    private func loadMessages() async {
        do {
            let fetched = try await GroupChatService.messages(groupChatId: groupChat.id, limit: pageSize)
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
            let older = try await GroupChatService.messagesBefore(
                groupChatId: groupChat.id, before: oldest.createdAt, limit: pageSize
            )
            hasMoreMessages = older.count >= pageSize
            messages = older + messages
        } catch where error.isCancellation {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadNewMessages() async {
        let latest = messages.last?.createdAt ?? Date.distantPast
        do {
            let newMessages = try await GroupChatService.messagesAfter(
                groupChatId: groupChat.id, after: latest
            )
            if !newMessages.isEmpty {
                messages.append(contentsOf: newMessages)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sendMessage() async {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        messageText = ""
        do {
            try await GroupChatService.sendMessage(groupChatId: groupChat.id, content: text)
            await loadNewMessages()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Group Chat Message Bubble

private struct GroupChatMessageBubble: View {
    let message: GroupChatMessage
    let isFromCurrentUser: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isFromCurrentUser {
                Spacer(minLength: 48)
            } else {
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

// MARK: - System Message

private struct SystemMessageView: View {
    let message: GroupChatMessage

    var body: some View {
        Text(message.content)
            .font(.system(size: 12))
            .foregroundColor(.stackSecondaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
    }
}
