import SwiftUI

struct InviteFriendSheet: View {
    let game: Game
    @Environment(\.dismiss) private var dismiss
    @State private var friends: [FriendRow] = []
    @State private var isLoading = true
    @State private var invitedIds: Set<UUID> = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if friends.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.stackSecondaryText)
                        Text("No friends to invite")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.stackSecondaryText)
                        Text("Add friends from your profile to invite them to games.")
                            .font(.system(size: 14))
                            .foregroundColor(.stackSecondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(friends) { friend in
                        HStack(spacing: 12) {
                            avatarImage(url: friend.avatarUrl, size: 40)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(friend.displayName)
                                    .font(.system(size: 15, weight: .semibold))
                                if let dupr = friend.duprRating {
                                    Text("DUPR \(String(format: "%.1f", dupr))")
                                        .font(.system(size: 13))
                                        .foregroundColor(.stackGreen)
                                }
                            }

                            Spacer()

                            if invitedIds.contains(friend.friendUserId) {
                                Text("Invited")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.stackSecondaryText)
                            } else {
                                Button {
                                    Task { await invite(friend) }
                                } label: {
                                    Text("Invite")
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
                    .listStyle(.insetGrouped)
                }
            }
            .background(Color.stackBackground)
            .navigationTitle("Invite Friends")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadFriends()
            }
            .errorAlert($errorMessage)
        }
    }

    private func loadFriends() async {
        isLoading = true
        do {
            guard let userId = await AuthService.currentUserId() else { return }
            friends = try await FriendService.getFriends(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func invite(_ friend: FriendRow) async {
        invitedIds.insert(friend.friendUserId)
        do {
            try await FriendService.inviteToGame(gameId: game.id, friendId: friend.friendUserId)
        } catch {
            invitedIds.remove(friend.friendUserId)
            errorMessage = error.localizedDescription
        }
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
