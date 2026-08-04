import SwiftUI

struct FriendsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = FriendsViewModel()
    var initiallyShowSearch: Bool = false
    @State private var isSearchActive: Bool = false

    var body: some View {
        List {
            // Search results
            if !viewModel.searchResults.isEmpty {
                Section("Search Results") {
                    ForEach(viewModel.searchResults) { user in
                        HStack(spacing: 12) {
                            avatarImage(url: user.avatarUrl, size: 40)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName)
                                    .font(AppFonts.body())
                                    .fontWeight(.semibold)
                                Text("@\(user.username)")
                                    .font(AppFonts.subheadline())
                                    .foregroundColor(.stackSecondaryText)
                            }

                            Spacer()

                            if viewModel.pendingSentIds.contains(user.id) {
                                Text("Sent")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.stackSecondaryText)
                            } else {
                                Button {
                                    Task { await viewModel.sendRequest(to: user.id) }
                                } label: {
                                    Image(systemName: "person.badge.plus")
                                        .font(.system(size: 16))
                                        .foregroundColor(.stackGreen)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            // Friends list
            Section(viewModel.friends.isEmpty ? "" : "Friends") {
                if viewModel.isLoading && viewModel.friends.isEmpty {
                    SkeletonList(count: 5) { SkeletonRow() }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                } else if viewModel.friends.isEmpty && viewModel.searchResults.isEmpty {
                    Text("No friends yet. Search for players above to add friends.")
                        .font(AppFonts.callout())
                        .foregroundColor(.stackSecondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    ForEach(viewModel.friends) { friend in
                        HStack(spacing: 12) {
                            avatarImage(url: friend.avatarUrl, size: 44)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(friend.displayName)
                                    .font(AppFonts.body())
                                    .fontWeight(.semibold)
                                HStack(spacing: 6) {
                                    Text("@\(friend.username)")
                                        .font(AppFonts.subheadline())
                                        .foregroundColor(.stackSecondaryText)
                                    if let dupr = friend.duprRating {
                                        HStack(spacing: 3) {
                                            if friend.isDuprConnected {
                                                Image(systemName: "checkmark.seal.fill")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.stackGreen)
                                            }
                                            Text("\(String(format: "%.1f", dupr)) DUPR")
                                                .font(AppFonts.caption())
                                                .fontWeight(.medium)
                                                .foregroundColor(.stackGreen)
                                        }
                                    }
                                }
                            }

                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { offsets in
                        guard let index = offsets.first else { return }
                        let friend = viewModel.friends[index]
                        Task { await viewModel.removeFriend(friend) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $viewModel.searchText, isPresented: $isSearchActive, prompt: "Search players by name")
        .onChange(of: viewModel.searchText) {
            Task { await viewModel.search() }
        }
        .navigationTitle(initiallyShowSearch ? "Add Friends" : "Friends")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            if initiallyShowSearch {
                isSearchActive = true
            }
        }
        .task {
            await viewModel.load()
            appState.pendingFriendRequestCount = viewModel.friendRequests.count
        }
        .refreshable {
            await viewModel.load()
            appState.pendingFriendRequestCount = viewModel.friendRequests.count
        }
        .onChange(of: viewModel.friendRequests.count) {
            appState.pendingFriendRequestCount = viewModel.friendRequests.count
        }
        .errorAlert($viewModel.errorMessage)
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
            .fill(Color(.tertiarySystemFill))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundColor(.white)
            )
    }
}

#Preview {
    NavigationStack {
        FriendsView()
    }
    .environment(AppState())
}
