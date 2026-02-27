import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SessionFlyerDetailView: View {
    let game: Game
    let isHost: Bool

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var participants: [ParticipantWithProfile] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingInviteFriend = false
    @State private var showingCopiedToast = false
    @State private var groupChatId: UUID?
    @State private var friendIds: Set<UUID> = []
    @State private var pendingSentIds: Set<UUID> = []

    private var isParticipant: Bool {
        guard let userId = appState.currentUser?.id else { return false }
        return isHost || participants.contains { $0.userId == userId }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Flyer card
                VStack(alignment: .leading, spacing: 12) {
                    // Format badges
                    HStack(spacing: 6) {
                        Text(game.gameFormat.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.stackGreen)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.stackBadgeBg)
                            .cornerRadius(8)

                        if game.friendsOnly {
                            HStack(spacing: 3) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 10))
                                Text("Friends Only")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.12))
                            .cornerRadius(8)
                        }

                        if let sessionType = game.sessionType, sessionType == .roundRobin {
                            Text("Round Robin")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.12))
                                .cornerRadius(8)
                        }
                    }

                    // Date & Time
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 13))
                            .foregroundColor(.stackSecondaryText)
                        (Text(game.gameDatetime, format: .dateTime.weekday(.wide))
                        + Text(", ")
                        + Text(game.gameDatetime, format: .dateTime.month(.abbreviated).day())
                        + Text(" at ")
                        + Text(game.gameDatetime, format: .dateTime.hour().minute()))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                    }

                    // Location
                    if let location = game.locationName {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin")
                                .font(.system(size: 13))
                                .foregroundColor(.stackSecondaryText)
                            Text(location)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                    }

                    // DUPR
                    if let min = game.skillLevelMin {
                        HStack(spacing: 6) {
                            Image(systemName: "trophy")
                                .font(.system(size: 13))
                                .foregroundColor(.stackSecondaryText)
                            Text("DUPR \(String(format: "%.1f", min))+")
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                    }

                    // Spots
                    HStack(spacing: 6) {
                        Image(systemName: "person.2")
                            .font(.system(size: 13))
                            .foregroundColor(.stackSecondaryText)
                        Text("\(game.spotsFilled)/\(game.spotsAvailable) spots filled")
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                    }

                    // Description
                    if let desc = game.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.stackCardWhite)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.black, lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Group Chat button
                if isParticipant, let chatId = groupChatId {
                    Button {
                        appState.pendingGroupChatId = chatId
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.stackGreen)
                            Text("Group Chat")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .background(Color.stackCardWhite)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.stackGreen.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }

                // Session Chat (existing game chat)
                if isParticipant {
                    NavigationLink {
                        GameChatView(
                            game: game,
                            currentUserId: appState.currentUser?.id ?? UUID()
                        )
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.stackGreen)
                            Text("Session Chat")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .background(Color.stackCardWhite)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.stackGreen.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                // Invite friends
                if isParticipant && game.spotsRemaining > 0 {
                    Button {
                        showingInviteFriend = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 16))
                                .foregroundColor(.stackGreen)
                            Text("Invite Friends")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .background(Color.stackCardWhite)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.stackGreen.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                // Players header
                HStack {
                    Text("Players (\(participants.count))")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 8)

                // Player list
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.top, 20)
                } else if participants.isEmpty {
                    Text("No players yet")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(participants) { participant in
                            FlyerPlayerRow(
                                participant: participant,
                                isHost: participant.userId == game.creatorId,
                                isSelf: participant.userId == appState.currentUser?.id,
                                isFriend: friendIds.contains(participant.userId),
                                isSent: pendingSentIds.contains(participant.userId),
                                onAddFriend: {
                                    Task { await sendFriendRequest(to: participant.userId) }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.top, 12)
                        .padding(.horizontal, 16)
                }

                Spacer(minLength: 24)
            }
        }
        .background(Color.stackBackground)
        .navigationTitle(game.sessionName ?? game.creatorDisplayName + "'s Session")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    copyLink()
                } label: {
                    Image(systemName: showingCopiedToast ? "checkmark" : "square.and.arrow.up")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(showingCopiedToast ? .stackGreen : .primary)
                }
            }
        }
        .task {
            async let loadParts: Void = loadParticipants()
            async let loadChat: Void = loadGroupChat()
            async let loadFriends: Void = loadFriendshipState()
            _ = await (loadParts, loadChat, loadFriends)
        }
        .sheet(isPresented: $showingInviteFriend) {
            InviteFriendSheet(game: game)
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

    private func loadGroupChat() async {
        do {
            let chat = try await GroupChatService.groupChatForGame(gameId: game.id)
            groupChatId = chat?.id
        } catch {
            // non-critical
        }
    }

    private func loadFriendshipState() async {
        guard let userId = appState.currentUser?.id else { return }
        do {
            async let friends = FriendService.getFriends(userId: userId)
            async let sentRequests = FriendService.getSentRequests(userId: userId)
            async let incomingRequests = FriendService.getFriendRequests(userId: userId)
            let f = try await friends
            let sent = try await sentRequests
            let incoming = try await incomingRequests
            friendIds = Set(f.map(\.friendUserId))
            pendingSentIds = Set(sent.map(\.friendId)).union(Set(incoming.map(\.friendUserId)))
        } catch {
            // non-critical
        }
    }

    private func sendFriendRequest(to userId: UUID) async {
        pendingSentIds.insert(userId)
        do {
            try await FriendService.sendFriendRequest(friendId: userId)
        } catch {
            pendingSentIds.remove(userId)
            errorMessage = error.localizedDescription
        }
    }

    private func copyLink() {
        let link = "stackpickleball://session/\(game.id.uuidString)"
        #if canImport(UIKit)
        UIPasteboard.general.string = link
        #endif
        withAnimation {
            showingCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showingCopiedToast = false
            }
        }
    }
}

// MARK: - Player Row for Flyer

private struct FlyerPlayerRow: View {
    let participant: ParticipantWithProfile
    let isHost: Bool
    let isSelf: Bool
    let isFriend: Bool
    let isSent: Bool
    var onAddFriend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if let avatarUrl = participant.users.avatarUrl, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        avatarPlaceholder
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            } else {
                avatarPlaceholder
                    .frame(width: 48, height: 48)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(participant.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)

                    if isHost {
                        HStack(spacing: 2) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 10))
                            Text("Host")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.orange)
                    }
                }

                if let rating = participant.users.duprRating {
                    Text("DUPR \(String(format: "%.1f", rating))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.stackGreen)
                }
            }

            Spacer()

            if !isSelf {
                if isFriend {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill.checkmark")
                            .font(.system(size: 13))
                        Text("Friends")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.stackSecondaryText)
                } else if isSent {
                    Text("Sent")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.stackSecondaryText)
                } else {
                    Button(action: onAddFriend) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 18))
                            .foregroundColor(.stackGreen)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.stackCardWhite)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            )
    }
}
