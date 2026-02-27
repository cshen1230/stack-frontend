import SwiftUI

struct AddMembersSheet: View {
    let groupChatId: UUID
    let existingMemberIds: Set<UUID>
    var onAdded: (() async -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var friends: [FriendRow] = []
    @State private var searchResults: [User] = []
    @State private var addedIds: Set<UUID> = []
    @State private var isAdding: UUID?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                let displayList: [(id: UUID, name: String, avatarUrl: String?)] = searchText.isEmpty
                    ? friends
                        .filter { !existingMemberIds.contains($0.friendUserId) }
                        .map { ($0.friendUserId, $0.displayName, $0.avatarUrl) }
                    : searchResults
                        .filter { !existingMemberIds.contains($0.id) }
                        .map { ($0.id, $0.displayName, $0.avatarUrl) }

                ForEach(displayList, id: \.id) { row in
                    HStack(spacing: 12) {
                        avatarImage(url: row.avatarUrl, size: 40)

                        Text(row.name)
                            .font(.system(size: 15, weight: .medium))

                        Spacer()

                        if addedIds.contains(row.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.stackGreen)
                        } else if isAdding == row.id {
                            ProgressView()
                        } else {
                            Button {
                                Task { await addMember(userId: row.id) }
                            } label: {
                                Text("Add")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Color.stackGreen)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search players")
            .onChange(of: searchText) {
                Task { await search() }
            }
            .navigationTitle("Add Members")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        Task {
                            await onAdded?()
                            dismiss()
                        }
                    }
                }
            }
            .task {
                await loadFriends()
            }
            .errorAlert($errorMessage)
        }
    }

    private func loadFriends() async {
        guard let userId = appState.currentUser?.id else { return }
        do {
            friends = try await FriendService.getFriends(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func search() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            searchResults = []
            return
        }
        do {
            let results = try await PlayerService.searchPlayers(query: query)
            let userId = appState.currentUser?.id
            searchResults = results.filter { $0.id != userId }
        } catch where error.isCancellation {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addMember(userId: UUID) async {
        isAdding = userId
        do {
            try await GroupChatService.addMember(groupChatId: groupChatId, userId: userId)
            addedIds.insert(userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isAdding = nil
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
