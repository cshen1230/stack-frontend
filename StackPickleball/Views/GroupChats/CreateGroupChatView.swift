import SwiftUI

struct CreateGroupChatView: View {
    var onCreated: (() async -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var chatName = ""
    @State private var searchText = ""
    @State private var friends: [FriendRow] = []
    @State private var searchResults: [User] = []
    @State private var selectedUserIds: Set<UUID> = []
    @State private var selectedUsers: [SelectedUser] = []
    @State private var isCreating = false
    @State private var errorMessage: String?

    struct SelectedUser: Identifiable {
        let id: UUID
        let name: String
        let avatarUrl: String?
    }

    private var canCreate: Bool {
        !chatName.trimmingCharacters(in: .whitespaces).isEmpty && !selectedUserIds.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Chat name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Group Name")
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
                            Text("Members (\(selectedUsers.count))")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(selectedUsers) { user in
                                        HStack(spacing: 6) {
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
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.stackGreen.opacity(0.12))
                                        .cornerRadius(16)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }

                    // Search
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add Members")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)

                        TextField("Search friends", text: $searchText)
                            .font(.system(size: 16))
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .onChange(of: searchText) {
                                filterResults()
                            }
                    }
                    .padding(.horizontal, 16)

                    // Results
                    let displayList = searchText.isEmpty ? friends.map { friendToRow($0) } : searchResults.map { userToRow($0) }
                    LazyVStack(spacing: 6) {
                        ForEach(displayList, id: \.id) { row in
                            let isSelected = selectedUserIds.contains(row.id)
                            Button {
                                toggleUser(row)
                            } label: {
                                HStack(spacing: 12) {
                                    avatarImage(url: row.avatarUrl, size: 40)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(row.name)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.primary)
                                    }

                                    Spacer()

                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundColor(isSelected ? .stackGreen : Color(.systemGray3))
                                }
                                .padding(12)
                                .background(Color.stackCardWhite)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isSelected ? Color.stackGreen.opacity(0.4) : Color.stackBorder, lineWidth: 1)
                                )
                            }
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
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color.stackBackground)
            .navigationTitle("New Group Chat")
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
        }
    }

    private struct UserRow: Identifiable {
        let id: UUID
        let name: String
        let avatarUrl: String?
    }

    private func friendToRow(_ friend: FriendRow) -> UserRow {
        UserRow(id: friend.friendUserId, name: friend.displayName, avatarUrl: friend.avatarUrl)
    }

    private func userToRow(_ user: User) -> UserRow {
        UserRow(id: user.id, name: user.displayName, avatarUrl: user.avatarUrl)
    }

    private func toggleUser(_ row: UserRow) {
        if selectedUserIds.contains(row.id) {
            removeUser(row.id)
        } else {
            selectedUserIds.insert(row.id)
            selectedUsers.append(SelectedUser(id: row.id, name: row.name, avatarUrl: row.avatarUrl))
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
    }

    private func filterResults() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard query.count >= 2 else {
            searchResults = []
            return
        }
        Task {
            do {
                let results = try await PlayerService.searchPlayers(query: query)
                let userId = appState.currentUser?.id
                searchResults = results.filter { $0.id != userId }
            } catch where error.isCancellation {
            } catch {
                errorMessage = error.localizedDescription
            }
        }
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
