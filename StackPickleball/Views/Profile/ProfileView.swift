import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = ProfileViewModel()
    @State private var friendsViewModel = FriendsViewModel()
    @State private var showingEditProfile = false
    /// Your standing weekly pattern — a setting you set once, not a place you visit, so it
    /// lives here rather than competing with the Schedule tab.
    @State private var scheduleViewModel = ScheduleViewModel()
    @State private var showingScheduleEditor = false
    private let friendRequestsScrollId = "friendRequests"

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading && viewModel.user == nil {
                    ScrollView {
                        VStack(spacing: 24) {
                            SkeletonBlock(height: 150, cornerRadius: 18)
                            SkeletonList(count: 3) { SkeletonRow() }
                        }
                        .padding(AppConstants.screenPadding)
                        .skeleton()
                    }
                } else if let user = viewModel.user {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 24) {
                                // Profile card with overlapping avatar
                                profileCard(user: user)

                                // DUPR connect prompt for unverified users
                                if !user.isDuprConnected {
                                    DUPRConnectView(
                                        onConnected: { _ in
                                            Task { await viewModel.loadProfile() }
                                        },
                                        allowSkip: false,
                                        isConnected: false
                                    )
                                }

                                friendsSection(proxy: proxy)

                                // Calendar section
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Past Sessions")
                                        .font(AppFonts.sectionTitle())
                                        .foregroundColor(.primary)
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
                                }

                                Spacer(minLength: 24)
                            }
                            .padding(.horizontal, AppConstants.screenPadding)
                            .padding(.top, 16)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .animation(Motion.content, value: viewModel.user != nil)
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
                if let userId = appState.currentUser?.id {
                    await scheduleViewModel.loadSchedule(userId: userId)
                }
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
            .sheet(isPresented: $showingScheduleEditor) {
                MyScheduleEditorSheet(viewModel: scheduleViewModel)
            }
            .errorAlert($viewModel.errorMessage)
        }
    }

    /// How many weekly windows are set, so the row says something before you tap it.
    private var weeklyAvailabilitySubtitle: String {
        let count = scheduleViewModel.mySchedule.count
        return count == 0 ? "Set the times you usually play" : "\(count) window\(count == 1 ? "" : "s") set"
    }

    // MARK: - Profile Card

    private func profileCard(user: User) -> some View {
        ZStack(alignment: .top) {
            // Card body
            VStack(spacing: 14) {
                // Display name
                Text(user.displayName)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.primary)

                // Username
                Button(action: { showingEditProfile = true }) {
                    HStack(spacing: 4) {
                        Text("@\(user.username)")
                            .font(AppFonts.body())
                            .foregroundColor(.stackSecondaryText)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.stackSecondaryText)
                    }
                }

                // DUPR badge
                if user.isDuprConnected {
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                            Text("DUPR Verified")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.stackDUPRBadge)
                        .cornerRadius(18)

                        HStack(spacing: 12) {
                            if let singles = user.duprSinglesRating {
                                Text("Singles: \(String(format: "%.2f", singles))")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.stackSecondaryText)
                            }
                            if let doubles = user.duprDoublesRating {
                                Text("Doubles: \(String(format: "%.2f", doubles))")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.stackSecondaryText)
                            }
                        }
                    }
                } else if let dupr = user.duprRating {
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
                    .background(Color.stackDUPRBadge.opacity(0.7))
                    .cornerRadius(18)
                } else {
                    Text("Beginner")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.stackSecondaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.stackFilterInactive)
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
                        .fill(Color(.separator))
                        .frame(width: 1, height: 36)

                    NavigationLink {
                        FriendsView()
                    } label: {
                        statItem(
                            label: "Friends",
                            value: "\(viewModel.friendCount)"
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 72)
            .padding(.bottom, 20)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardCornerRadius))
            .shadow(
                color: .black.opacity(AppConstants.shadowOpacity),
                radius: AppConstants.shadowBlur,
                y: AppConstants.shadowYOffset
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
                .foregroundColor(.primary)
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
            Text("Friends")
                .font(AppFonts.sectionTitle())
                .foregroundColor(.primary)
                .padding(.leading, 4)

            friendsQuickActionsCard(proxy: proxy)

            if !friendsViewModel.friendRequests.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Friend Requests")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.top, 6)
                        .id(friendRequestsScrollId)

                    VStack(spacing: 10) {
                        ForEach(friendsViewModel.friendRequests) { request in
                            friendRequestRow(request)
                        }
                    }
                }
                .cardStyle()
            }
        }
    }

    private func friendsQuickActionsCard(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(Motion.content) {
                    proxy.scrollTo(friendRequestsScrollId, anchor: .top)
                }
            } label: {
                quickActionRowContent(
                    title: "Friend Requests",
                    subtitle: friendsViewModel.friendRequests.isEmpty
                        ? "No pending requests"
                        : "\(friendsViewModel.friendRequests.count) pending",
                    systemImage: "person.crop.circle.badge.plus",
                    trailingCount: friendsViewModel.friendRequests.isEmpty ? nil : friendsViewModel.friendRequests.count
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .disabled(friendsViewModel.friendRequests.isEmpty)
            .opacity(friendsViewModel.friendRequests.isEmpty ? 0.6 : 1)

            Divider()
                .padding(.leading, 14 + 44 + 12) // left padding + icon + spacing

            NavigationLink {
                FriendsView(initiallyShowSearch: true)
            } label: {
                quickActionRowContent(
                    title: "Add Friends",
                    subtitle: "Search players by name",
                    systemImage: "person.badge.plus"
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            Divider()
                .padding(.leading, 14 + 44 + 12)

            NavigationLink {
                FriendsView()
            } label: {
                quickActionRowContent(
                    title: "View Friends",
                    subtitle: "\(viewModel.friendCount) friends",
                    systemImage: "person.2"
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            Divider()
                .padding(.leading, 14 + 44 + 12)

            Button {
                showingScheduleEditor = true
            } label: {
                quickActionRowContent(
                    title: "Weekly Availability",
                    subtitle: weeklyAvailabilitySubtitle,
                    systemImage: "calendar"
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardCornerRadius))
        .shadow(
            color: .black.opacity(AppConstants.shadowOpacity),
            radius: AppConstants.shadowBlur,
            y: AppConstants.shadowYOffset
        )
    }

    private func quickActionRowContent(
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
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(AppFonts.subheadline())
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
    }

    private func friendRequestRow(_ request: FriendRow) -> some View {
        HStack(spacing: 12) {
            friendAvatarImage(url: request.avatarUrl, size: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(request.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)

                if let dupr = request.duprRating {
                    HStack(spacing: 3) {
                        if request.isDuprConnected {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.stackGreen)
                        }
                        Text("DUPR \(String(format: "%.1f", dupr))")
                            .font(AppFonts.subheadline())
                            .foregroundColor(.stackGreen)
                    }
                } else {
                    Text("@\(request.username)")
                        .font(AppFonts.subheadline())
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
        .background(Color(.secondarySystemBackground))
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
