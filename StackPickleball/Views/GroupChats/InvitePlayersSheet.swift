import SwiftUI

struct InvitePlayersSheet: View {
    @Binding var selectedUserIds: Set<UUID>
    @Binding var selectedUsers: [CreateGroupChatView.SelectedUser]
    let friendIds: Set<UUID>

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var searchResults: [User] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundColor(Color(.tertiaryLabel))
                    TextField("Search by name or username", text: $searchText)
                        .font(.system(size: 16))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { Task { await search() } }
                        .onChange(of: searchText) {
                            Task { await search() }
                        }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                            hasSearched = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(.tertiaryLabel))
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

                Divider()

                // Results
                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                    // Prompt state
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(Color(.tertiaryLabel))
                        Text("Search for players to invite")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(.secondaryLabel))
                        Text("Type at least 2 characters to search")
                            .font(.system(size: 13))
                            .foregroundColor(Color(.tertiaryLabel))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else if isSearching {
                    VStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else if searchResults.isEmpty && hasSearched {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "person.slash")
                            .font(.system(size: 36))
                            .foregroundColor(Color(.tertiaryLabel))
                        Text("No players found")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(.secondaryLabel))
                        Text("Try a different name or username")
                            .font(.system(size: 13))
                            .foregroundColor(Color(.tertiaryLabel))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(searchResults) { user in
                                let isSelected = selectedUserIds.contains(user.id)
                                let isFriend = friendIds.contains(user.id)
                                Button {
                                    toggleUser(user)
                                } label: {
                                    HStack(spacing: 12) {
                                        avatarImage(url: user.avatarUrl, size: 44)

                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 6) {
                                                Text(user.displayName)
                                                    .font(.system(size: 15, weight: .medium))
                                                    .foregroundColor(.primary)
                                                if isFriend {
                                                    Text("Friend")
                                                        .font(.system(size: 10, weight: .semibold))
                                                        .foregroundColor(.stackGreen)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Color.stackGreen.opacity(0.1))
                                                        .cornerRadius(4)
                                                }
                                            }
                                            if !user.username.isEmpty {
                                                Text("@\(user.username)")
                                                    .font(.system(size: 13))
                                                    .foregroundColor(Color(.secondaryLabel))
                                            }
                                        }

                                        Spacer()

                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                                            .font(.system(size: 22))
                                            .foregroundColor(isSelected ? .stackGreen : Color(.systemGray3))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(isSelected ? Color.stackGreen.opacity(0.04) : Color.clear)
                                }

                                if user.id != searchResults.last?.id {
                                    Divider()
                                        .padding(.leading, 72)
                                }
                            }
                        }
                    }
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("Invite Players")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .errorAlert($errorMessage)
        }
    }

    // MARK: - Actions

    private func toggleUser(_ user: User) {
        if selectedUserIds.contains(user.id) {
            selectedUserIds.remove(user.id)
            selectedUsers.removeAll { $0.id == user.id }
        } else {
            selectedUserIds.insert(user.id)
            selectedUsers.append(CreateGroupChatView.SelectedUser(
                id: user.id,
                name: user.displayName,
                avatarUrl: user.avatarUrl
            ))
        }
    }

    private func search() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            searchResults = []
            hasSearched = false
            return
        }
        isSearching = true
        do {
            let results = try await PlayerService.searchPlayers(query: query)
            let userId = appState.currentUser?.id
            searchResults = results.filter { $0.id != userId }
            hasSearched = true
        } catch where error.isCancellation {
        } catch {
            errorMessage = error.localizedDescription
        }
        isSearching = false
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
