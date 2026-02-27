import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = ProfileViewModel()
    @State private var friendsViewModel = FriendsViewModel()
    @State private var showingEditProfile = false
    private let friendRequestsScrollId = "friendRequests"

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading && viewModel.user == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let user = viewModel.user {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 24) {
                                // Profile card with overlapping avatar
                                profileCard(user: user)

                                friendsSection(proxy: proxy)

                                // Calendar section
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Past Sessions")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.leading, 4)

                                    SessionCalendarView(
                                        pastGames: viewModel.pastGames,
                                        currentUserId: appState.currentUser?.id
                                    )
                                }

                                // Sign out
                                Button(action: {
                                    Task { await viewModel.signOut() }
                                }) {
                                    HStack(spacing: 8) {
                                        Text("Sign Out")
                                            .font(.system(size: 16, weight: .semibold))
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                            .font(.system(size: 15))
                                    }
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 14)
                                    .background(Color.white)
                                    .cornerRadius(14)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.black, lineWidth: 1)
                                    )
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color.red)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .stroke(Color.black, lineWidth: 1)
                                            )
                                            .offset(x: 3, y: 4)
                                    )
                                }

                                Spacer(minLength: 24)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.25), value: viewModel.user != nil)
            .background(Color.stackBackground)
            .navigationTitle("Profile")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingEditProfile = true }) {
                        Text("Edit")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.stackGreen)
                    }
                }
            }
            .task {
                await viewModel.loadProfile()
                await friendsViewModel.load()
                appState.pendingFriendRequestCount = friendsViewModel.friendRequests.count
            }
            .refreshable {
                await viewModel.loadProfile()
                await friendsViewModel.load()
                appState.pendingFriendRequestCount = friendsViewModel.friendRequests.count
            }
            .onChange(of: friendsViewModel.friendRequests.count) {
                appState.pendingFriendRequestCount = friendsViewModel.friendRequests.count
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView(viewModel: viewModel)
            }
            .errorAlert($viewModel.errorMessage)
        }
    }

    // MARK: - Profile Card

    private func profileCard(user: User) -> some View {
        ZStack(alignment: .top) {
            // Card body
            VStack(spacing: 14) {
                // Display name
                Text(user.displayName)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.black)

                // Username
                Button(action: { showingEditProfile = true }) {
                    HStack(spacing: 4) {
                        Text("@\(user.username)")
                            .font(.system(size: 15))
                            .foregroundColor(.stackSecondaryText)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.stackSecondaryText)
                    }
                }

                // DUPR badge
                if let dupr = user.duprRating {
                    HStack(spacing: 6) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                        Text("\(String(format: "%.1f", dupr)) DUPR")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.stackDUPRBadge)
                    .cornerRadius(18)
                }

                // Stats row
                Divider()
                    .padding(.horizontal, 8)
                    .padding(.top, 4)

                HStack(spacing: 0) {
                    statItem(
                        label: "Total Sessions",
                        value: "\(viewModel.pastGames.count)"
                    )

                    Rectangle()
                        .fill(Color.stackBorder)
                        .frame(width: 1, height: 36)

                    statItem(
                        label: "Friends",
                        value: "\(viewModel.friendCount)"
                    )
                }
                .padding(.bottom, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 72)
            .padding(.bottom, 20)
            .background(Color.white)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.black, lineWidth: 1)
            )
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.stackGreen)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.black, lineWidth: 1)
                    )
                    .offset(x: 3, y: 4)
            )
            .padding(.top, 60)

            // Avatar — overlapping the card top
            ZStack {
                if let avatarUrl = user.avatarUrl, let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        avatarPlaceholder
                    }
                    .frame(width: 110, height: 110)
                    .clipShape(Circle())
                } else {
                    avatarPlaceholder
                }
            }
            .overlay(
                Circle()
                    .stroke(Color.stackGreen.opacity(0.4), lineWidth: 4)
                    .frame(width: 120, height: 120)
            )
            .zIndex(1)
        }
    }

    // MARK: - Stat Item

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.stackSecondaryText)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.black)
        }
        .frame(maxWidth: .infinity)
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 110, height: 110)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            )
    }

    // MARK: - Friends Section (moved from Friends tab)

    private func friendsSection(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Friends")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.leading, 4)

                Spacer()

                NavigationLink {
                    FriendsView()
                } label: {
                    HStack(spacing: 6) {
                        Text("View Friends")
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.stackGreen)
                }
            }

            VStack(spacing: 10) {
                Button {
                    guard !friendsViewModel.friendRequests.isEmpty else { return }
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(friendRequestsScrollId, anchor: .top)
                    }
                } label: {
                    quickActionRow(
                        title: "Friend Requests",
                        subtitle: friendsViewModel.friendRequests.isEmpty
                            ? "No pending requests"
                            : "\(friendsViewModel.friendRequests.count) pending",
                        systemImage: "person.crop.circle.badge.plus",
                        trailingCount: friendsViewModel.friendRequests.isEmpty ? nil : friendsViewModel.friendRequests.count
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    FriendsView()
                } label: {
                    quickActionRow(
                        title: "View Friends",
                        subtitle: "See your friends and add more",
                        systemImage: "person.2"
                    )
                }
                .buttonStyle(.plain)
            }

            if !friendsViewModel.friendRequests.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Friend Requests")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.top, 6)
                        .id(friendRequestsScrollId)

                    VStack(spacing: 10) {
                        ForEach(friendsViewModel.friendRequests) { request in
                            friendRequestRow(request)
                        }
                    }
                }
                .padding(14)
                .background(Color.white)
                .cornerRadius(18)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.black, lineWidth: 1)
                )
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.stackGreen)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.black, lineWidth: 1)
                        )
                        .offset(x: 3, y: 4)
                )
            }
        }
    }

    private func quickActionRow(
        title: String,
        subtitle: String,
        systemImage: String,
        trailingCount: Int? = nil
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.stackFilterInactive)
                    .frame(width: 44, height: 44)
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.stackGreen)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.stackSecondaryText)
            }

            Spacer()

            if let trailingCount {
                Text("\(trailingCount)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.stackGreen)
                    .cornerRadius(999)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.stackSecondaryText)
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.black, lineWidth: 1)
        )
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.stackGreen)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.black, lineWidth: 1)
                )
                .offset(x: 3, y: 4)
        )
    }

    private func friendRequestRow(_ request: FriendRow) -> some View {
        HStack(spacing: 12) {
            friendAvatarImage(url: request.avatarUrl, size: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(request.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)

                if let dupr = request.duprRating {
                    Text("DUPR \(String(format: "%.1f", dupr))")
                        .font(.system(size: 13))
                        .foregroundColor(.stackGreen)
                } else {
                    Text("@\(request.username)")
                        .font(.system(size: 13))
                        .foregroundColor(.stackSecondaryText)
                }
            }

            Spacer()

            Button {
                Task {
                    await friendsViewModel.acceptRequest(request)
                    await viewModel.loadProfile()
                }
            } label: {
                Text("Accept")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.stackGreen)
                    .cornerRadius(10)
            }

            Button {
                Task { await friendsViewModel.declineRequest(request) }
            } label: {
                Text("Decline")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.stackSecondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.stackFilterInactive)
                    .cornerRadius(10)
            }
        }
        .padding(12)
        .background(Color.stackGameDetailBg)
        .cornerRadius(14)
    }

    private func friendAvatarImage(url: String?, size: CGFloat) -> some View {
        Group {
            if let avatarUrl = url, let imageUrl = URL(string: avatarUrl) {
                AsyncImage(url: imageUrl) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    friendAvatarPlaceholder(size: size)
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                friendAvatarPlaceholder(size: size)
            }
        }
    }

    private func friendAvatarPlaceholder(size: CGFloat) -> some View {
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
    ProfileView()
        .environment(AppState())
        .environmentObject(LocationManager.shared)
}
