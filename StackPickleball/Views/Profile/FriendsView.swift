import SwiftUI

struct FriendsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = FriendsViewModel()

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
                                    .font(.system(size: 15, weight: .semibold))
                                Text("@\(user.username)")
                                    .font(.system(size: 13))
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

            // Pending requests
            if !viewModel.friendRequests.isEmpty {
                Section("Friend Requests") {
                    ForEach(viewModel.friendRequests) { request in
                        HStack(spacing: 12) {
                            avatarImage(url: request.avatarUrl, size: 40)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(request.displayName)
                                    .font(.system(size: 15, weight: .semibold))
                                if let dupr = request.duprRating {
                                    Text("DUPR \(String(format: "%.1f", dupr))")
                                        .font(.system(size: 13))
                                        .foregroundColor(.stackGreen)
                                }
                            }

                            Spacer()

                            Button {
                                Task { await viewModel.acceptRequest(request) }
                            } label: {
                                Text("Accept")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.stackGreen)
                                    .cornerRadius(8)
                            }

                            Button {
                                Task { await viewModel.declineRequest(request) }
                            } label: {
                                Text("Decline")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.stackSecondaryText)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.stackFilterInactive)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            // Friends list
            Section(viewModel.friends.isEmpty ? "" : "Friends") {
                if viewModel.isLoading && viewModel.friends.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if viewModel.friends.isEmpty && viewModel.searchResults.isEmpty {
                    Text("No friends yet. Search for players above to add friends.")
                        .font(.system(size: 14))
                        .foregroundColor(.stackSecondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    ForEach(viewModel.friends) { friend in
                        HStack(spacing: 12) {
                            avatarImage(url: friend.avatarUrl, size: 44)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(friend.displayName)
                                    .font(.system(size: 15, weight: .semibold))
                                HStack(spacing: 6) {
                                    Text("@\(friend.username)")
                                        .font(.system(size: 13))
                                        .foregroundColor(.stackSecondaryText)
                                    if let dupr = friend.duprRating {
                                        Text("\(String(format: "%.1f", dupr)) DUPR")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.stackGreen)
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
        .searchable(text: $viewModel.searchText, prompt: "Search players by name")
        .onChange(of: viewModel.searchText) {
            Task { await viewModel.search() }
        }
        .navigationTitle("Friends")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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
            .fill(Color.gray.opacity(0.3))
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
