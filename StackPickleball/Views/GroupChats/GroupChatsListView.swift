import SwiftUI

struct GroupChatsListView: View {
    @Binding var selectedTab: Int

    @Environment(AppState.self) private var appState
    @State private var viewModel = GroupChatsViewModel()
    @State private var navigationPath = NavigationPath()
    @State private var showingCreateSheet = false
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?

    private var filteredChats: [GroupChat] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return viewModel.groupChats }
        return viewModel.groupChats.filter { chat in
            chat.name.lowercased().contains(query)
            || (chat.lastMessageContent?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if viewModel.isLoading && viewModel.groupChats.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.groupChats.isEmpty && viewModel.discoverableResults.isEmpty {
                    EmptyStateView(
                        icon: "bubble.left.and.text.bubble.right",
                        title: "No Communities Yet",
                        message: "Create a community with friends or join a session to start connecting!",
                        buttonTitle: "New Community",
                        buttonAction: { showingCreateSheet = true }
                    )
                } else {
                    List {
                        if !filteredChats.isEmpty {
                            ForEach(filteredChats) { groupChat in
                                ZStack {
                                    NavigationLink(value: groupChat) { EmptyView() }
                                        .opacity(0)
                                    GroupChatRow(groupChat: groupChat)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        if groupChat.createdBy == appState.currentUser?.id && groupChat.gameId == nil {
                                            Task { await viewModel.deleteGroupChat(groupChat) }
                                        } else {
                                            Task { await viewModel.leaveGroupChat(groupChat) }
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .tint(.red)

                                    Button {
                                        // Archive / mute placeholder
                                    } label: {
                                        Label("Mute", systemImage: "bell.slash")
                                    }
                                    .tint(Color(.systemGray))
                                }
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowSeparator(.visible)
                                .listRowSeparatorTint(Color(.separator).opacity(0.3))
                                .listRowBackground(Color(.systemBackground))
                            }
                        }

                        // Discover section
                        if !viewModel.discoverableResults.isEmpty {
                            Section {
                                ForEach(viewModel.discoverableResults) { community in
                                    DiscoverableCommunityRow(community: community) {
                                        Task {
                                            await viewModel.joinCommunity(community)
                                            if let joined = viewModel.groupChats.first(where: { $0.id == community.id }) {
                                                navigationPath.append(joined)
                                            }
                                        }
                                    }
                                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                    .listRowSeparator(.visible)
                                    .listRowSeparatorTint(Color(.separator).opacity(0.3))
                                    .listRowBackground(Color(.systemBackground))
                                }
                            } header: {
                                Text("Discover")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.stackSecondaryText)
                                    .textCase(nil)
                            }
                        }

                        if viewModel.isSearching {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding(.vertical, 12)
                                Spacer()
                            }
                            .listRowBackground(Color(.systemBackground))
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, prompt: "Search communities")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .navigationTitle("Communities")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showingCreateSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .navigationDestination(for: GroupChat.self) { groupChat in
                GroupChatDetailView(
                    groupChat: groupChat,
                    currentUserId: appState.currentUser?.id ?? UUID()
                )
            }
            .task {
                await viewModel.load()
            }
            .onAppear {
                Task { await viewModel.load() }
            }
            .refreshable {
                await viewModel.load()
            }
            .onChange(of: searchText) {
                searchTask?.cancel()
                let query = searchText
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    viewModel.discoverableResults = []
                    return
                }
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    guard !Task.isCancelled else { return }
                    await viewModel.searchDiscoverable(query: query)
                }
            }
            .onChange(of: selectedTab) {
                if selectedTab != 2 {
                    navigationPath = NavigationPath()
                }
            }
            .onChange(of: appState.pendingGroupChatId) {
                if let chatId = appState.pendingGroupChatId {
                    if let chat = viewModel.groupChats.first(where: { $0.id == chatId }) {
                        navigationPath = NavigationPath()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            navigationPath.append(chat)
                        }
                    } else {
                        Task {
                            await viewModel.load()
                            if let chat = viewModel.groupChats.first(where: { $0.id == chatId }) {
                                navigationPath = NavigationPath()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    navigationPath.append(chat)
                                }
                            }
                        }
                    }
                    appState.pendingGroupChatId = nil
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateGroupChatView {
                    await viewModel.load()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .errorAlert($viewModel.errorMessage)
        }
    }
}

// MARK: - Group Chat Row (GroupMe style)

private struct GroupChatRow: View {
    let groupChat: GroupChat

    // Stable color from chat name for initials avatar
    private var avatarColor: Color {
        let colors: [Color] = [
            .red, .orange, .green, .blue, .purple, .pink,
            Color(.systemTeal), Color(.systemIndigo),
            Color(red: 0.9, green: 0.3, blue: 0.3),
            Color(red: 0.2, green: 0.6, blue: 0.4),
        ]
        let hash = abs(groupChat.name.hashValue)
        return colors[hash % colors.count]
    }

    private var initials: String {
        let words = groupChat.name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        }
        return String(groupChat.name.prefix(2)).uppercased()
    }

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            chatAvatar

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                // Name + timestamp
                HStack(alignment: .firstTextBaseline) {
                    Text(groupChat.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if let lastAt = groupChat.lastMessageAt {
                        Text(relativeTime(from: lastAt))
                            .font(.system(size: 13))
                            .foregroundColor(Color(.secondaryLabel))
                    }
                }

                // Last message preview
                if let preview = groupChat.lastMessagePreview {
                    Text(preview)
                        .font(.system(size: 14))
                        .foregroundColor(Color(.secondaryLabel))
                        .lineLimit(2)
                } else {
                    Text("No messages yet")
                        .font(.system(size: 14))
                        .foregroundColor(Color(.tertiaryLabel))
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var chatAvatar: some View {
        if let firstUrl = groupChat.memberAvatarUrls?.first,
           let imageURL = URL(string: firstUrl),
           groupChat.avatarUrl == nil {
            // Use first member's avatar as the group avatar
            AsyncImage(url: imageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                initialsAvatar
            }
            .frame(width: 52, height: 52)
            .clipShape(Circle())
        } else if let avatarUrl = groupChat.avatarUrl,
                  let imageURL = URL(string: avatarUrl) {
            AsyncImage(url: imageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                initialsAvatar
            }
            .frame(width: 52, height: 52)
            .clipShape(Circle())
        } else {
            initialsAvatar
        }
    }

    private var initialsAvatar: some View {
        Text(initials)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 52, height: 52)
            .background(Circle().fill(avatarColor))
    }

    private func relativeTime(from date: Date) -> String {
        let elapsed = Date().timeIntervalSince(date)
        if elapsed < 60 { return "now" }
        let minutes = Int(elapsed / 60)
        if minutes < 60 { return "\(minutes) mins ago" }
        let hours = Int(elapsed / 3600)
        if hours < 24 { return "\(hours) hrs ago" }
        let days = Int(elapsed / 86400)
        if days == 1 { return "Yesterday" }
        if days < 7 { return "\(days) days ago" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Discoverable Community Row

private struct DiscoverableCommunityRow: View {
    let community: GroupChat
    let onJoin: () -> Void

    private var avatarColor: Color {
        let colors: [Color] = [
            .red, .orange, .green, .blue, .purple, .pink,
            Color(.systemTeal), Color(.systemIndigo),
            Color(red: 0.9, green: 0.3, blue: 0.3),
            Color(red: 0.2, green: 0.6, blue: 0.4),
        ]
        let hash = abs(community.name.hashValue)
        return colors[hash % colors.count]
    }

    private var initials: String {
        let words = community.name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        }
        return String(community.name.prefix(2)).uppercased()
    }

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            if let firstUrl = community.memberAvatarUrls?.first,
               let imageURL = URL(string: firstUrl) {
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initialsAvatar
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            } else {
                initialsAvatar
            }

            // Name + member count
            VStack(alignment: .leading, spacing: 3) {
                Text(community.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "person.2")
                        .font(.system(size: 11))
                    Text("\(community.memberCount ?? 0) members")
                        .font(.system(size: 13))
                }
                .foregroundColor(.stackSecondaryText)
            }

            Spacer()

            // Join button or Invite Only label
            if community.visibility == .public {
                Button(action: onJoin) {
                    Text("Join")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(Color.stackGreen)
                        .cornerRadius(18)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "lock.open")
                        .font(.system(size: 11))
                    Text("Invite Only")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.stackSecondaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var initialsAvatar: some View {
        Text(initials)
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 48, height: 48)
            .background(Circle().fill(avatarColor))
    }
}

// MARK: - Group Chat Avatar Collage (kept for use elsewhere)

struct GroupChatAvatarCollage: View {
    let avatarURLs: [String]
    let totalMembers: Int

    private var displayCount: Int { min(totalMembers, 4) }
    private var overflow: Int { max(0, totalMembers - 4) }

    private func positions(for count: Int) -> [(x: CGFloat, y: CGFloat, size: CGFloat)] {
        switch count {
        case 0, 1:
            return [(0, 0, 56)]
        case 2:
            return [
                (-8, -6, 38),
                (8, 6, 38),
            ]
        case 3:
            return [
                (0, -10, 34),
                (-11, 8, 30),
                (11, 8, 30),
            ]
        default:
            return [
                (-9, -9, 30),
                (9, -9, 30),
                (-9, 9, 30),
                (9, 9, 30),
            ]
        }
    }

    var body: some View {
        let pos = positions(for: displayCount)

        ZStack {
            ForEach(Array(0..<max(displayCount, 1)), id: \.self) { i in
                let url: String? = i < avatarURLs.count ? avatarURLs[i] : nil
                avatarCircle(url: url, size: pos[i].size)
                    .offset(x: pos[i].x, y: pos[i].y)
            }

            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                    .offset(x: 20, y: 20)
            }
        }
        .frame(width: 62, height: 62)
    }

    @ViewBuilder
    private func avatarCircle(url: String?, size: CGFloat) -> some View {
        Group {
            if let url, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    placeholderCircle(size: size)
                }
            } else {
                placeholderCircle(size: size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
    }

    private func placeholderCircle(size: CGFloat) -> some View {
        Circle()
            .fill(Color.gray.opacity(0.25))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.36))
                    .foregroundColor(.white)
            )
    }
}
