import SwiftUI

struct CreateGroupChatView: View {
    var onCreated: (() async -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var chatName = ""
    @State private var friendFilter = ""
    @State private var friends: [FriendRow] = []
    @State private var selectedUserIds: Set<UUID> = []
    @State private var selectedUsers: [SelectedUser] = []
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showingInvitePlayers = false
    @State private var isLoadingFriends = true

    struct SelectedUser: Identifiable, Equatable {
        let id: UUID
        let name: String
        let avatarUrl: String?

        static func == (lhs: SelectedUser, rhs: SelectedUser) -> Bool {
            lhs.id == rhs.id
        }
    }

    private var canCreate: Bool {
        !chatName.trimmingCharacters(in: .whitespaces).isEmpty && !selectedUserIds.isEmpty
    }

    private var filteredFriends: [FriendRow] {
        let query = friendFilter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return friends }
        return friends.filter { $0.displayName.lowercased().contains(query) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Community name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Community Name")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        TextField("e.g. Tuesday Crew", text: $chatName)
                            .font(.system(size: 16))
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 16)

                    // Selected members chips
                    if !selectedUsers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Selected (\(selectedUsers.count))")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.stackSecondaryText)
                                .padding(.horizontal, 16)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(selectedUsers) { user in
                                        HStack(spacing: 6) {
                                            avatarImage(url: user.avatarUrl, size: 22)
                                            Text(user.name)
                                                .font(.system(size: 13, weight: .medium))
                                            Button {
                                                removeUser(user.id)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.stackSecondaryText)
                                            }
                                        }
                                        .padding(.leading, 4)
                                        .padding(.trailing, 8)
                                        .padding(.vertical, 5)
                                        .background(Color.stackGreen.opacity(0.1))
                                        .cornerRadius(20)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }

                    // Friends section
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Friends")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                            Spacer()
                            if friends.count > 6 {
                                Image(systemName: "line.3.horizontal.decrease")
                                    .font(.system(size: 14))
                                    .foregroundColor(.stackSecondaryText)
                            }
                        }
                        .padding(.horizontal, 16)

                        // Inline filter for friends (only show when > 6 friends)
                        if friends.count > 6 {
                            TextField("Filter friends", text: $friendFilter)
                                .font(.system(size: 15))
                                .padding(10)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .padding(.horizontal, 16)
                        }

                        if isLoadingFriends {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding(.vertical, 20)
                                Spacer()
                            }
                        } else if friends.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "person.2.slash")
                                    .font(.system(size: 28))
                                    .foregroundColor(Color(.tertiaryLabel))
                                Text("No friends yet")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(.tertiaryLabel))
                                Text("Invite players below to add them")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(.quaternaryLabel))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        } else {
                            LazyVStack(spacing: 2) {
                                ForEach(filteredFriends, id: \.friendUserId) { friend in
                                    let isSelected = selectedUserIds.contains(friend.friendUserId)
                                    Button {
                                        toggleFriend(friend)
                                    } label: {
                                        HStack(spacing: 12) {
                                            avatarImage(url: friend.avatarUrl, size: 40)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(friend.displayName)
                                                    .font(.system(size: 15, weight: .medium))
                                                    .foregroundColor(.primary)
                                                if let rating = friend.duprRating {
                                                    Text("DUPR \(String(format: "%.1f", rating))")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.stackGreen)
                                                }
                                            }

                                            Spacer()

                                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 22))
                                                .foregroundColor(isSelected ? .stackGreen : Color(.systemGray3))
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(isSelected ? Color.stackGreen.opacity(0.04) : Color.clear)
                                    }
                                }
                            }
                        }
                    }

                    // Invite Players button
                    Button {
                        showingInvitePlayers = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 15))
                                .foregroundColor(.stackGreen)
                            Text("Invite Players")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.stackGreen)
                            Spacer()
                            Text("Search by name")
                                .font(.system(size: 13))
                                .foregroundColor(Color(.tertiaryLabel))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(.tertiaryLabel))
                        }
                        .padding(14)
                        .background(Color.stackGreen.opacity(0.06))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.stackGreen.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 16)

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.systemBackground))
            .navigationTitle("New Community")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await createGroupChat() }
                    } label: {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text("Create")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!canCreate || isCreating)
                }
            }
            .task {
                await loadFriends()
            }
            .sheet(isPresented: $showingInvitePlayers) {
                InvitePlayersSheet(
                    selectedUserIds: $selectedUserIds,
                    selectedUsers: $selectedUsers,
                    friendIds: Set(friends.map(\.friendUserId))
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Actions

    private func toggleFriend(_ friend: FriendRow) {
        if selectedUserIds.contains(friend.friendUserId) {
            removeUser(friend.friendUserId)
        } else {
            selectedUserIds.insert(friend.friendUserId)
            selectedUsers.append(SelectedUser(
                id: friend.friendUserId,
                name: friend.displayName,
                avatarUrl: friend.avatarUrl
            ))
        }
    }

    private func removeUser(_ id: UUID) {
        selectedUserIds.remove(id)
        selectedUsers.removeAll { $0.id == id }
    }

    private func loadFriends() async {
        guard let userId = appState.currentUser?.id else { return }
        do {
            friends = try await FriendService.getFriends(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingFriends = false
    }

    private func createGroupChat() async {
        isCreating = true
        let name = chatName.trimmingCharacters(in: .whitespaces)
        do {
            try await GroupChatService.createGroupChat(
                name: name,
                memberIds: Array(selectedUserIds)
            )
            await onCreated?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isCreating = false
    }

    // MARK: - Avatar helpers

    private func avatarImage(url: String?, size: CGFloat) -> some View {
        Group {
            if let avatarUrl = url, let imageUrl = URL(string: avatarUrl) {
                AsyncImage(url: imageUrl) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    avatarPlaceholder(size: size)
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                avatarPlaceholder(size: size)
            }
        }
    }

    private func avatarPlaceholder(size: CGFloat) -> some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundColor(.white)
            )
    }
}
