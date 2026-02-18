import SwiftUI

struct GameChatView: View {
    let game: Game
    let currentUserId: UUID

    @State private var messages: [GameMessage] = []
    @State private var messageText = ""
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    if isLoading {
                        ProgressView()
                            .padding(.top, 40)
                    } else if messages.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("No messages yet")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                            Text("Start the conversation!")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .padding(.top, 60)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(messages) { message in
                                MessageBubble(
                                    message: message,
                                    isFromCurrentUser: message.userId == currentUserId
                                )
                                .id(message.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input bar
            HStack(spacing: 12) {
                TextField("Message...", text: $messageText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)

                Button {
                    Task { await sendMessage() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(
                            messageText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? .gray : .stackGreen
                        )
                }
                .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.stackCardWhite)
        }
        .navigationTitle(game.sessionName ?? "Chat")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await loadMessages()
        }
        .refreshable {
            await loadMessages()
        }
    }

    private func loadMessages() async {
        do {
            messages = try await MessageService.messages(gameId: game.id)
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func sendMessage() async {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        messageText = ""
        do {
            try await MessageService.sendMessage(gameId: game.id, content: text)
            await loadMessages()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: GameMessage
    let isFromCurrentUser: Bool

    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer(minLength: 60) }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 2) {
                if !isFromCurrentUser {
                    Text(message.senderDisplayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isFromCurrentUser ? Color.stackGreen : Color(.systemGray5))
                    .cornerRadius(16)

                Text(message.createdAt, format: .dateTime.hour().minute())
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            if !isFromCurrentUser { Spacer(minLength: 60) }
        }
    }
}
