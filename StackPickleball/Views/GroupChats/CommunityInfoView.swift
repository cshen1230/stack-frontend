import SwiftUI

struct CommunityInfoView: View {
    let groupChat: GroupChat
    let currentUserId: UUID
    let onLeave: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var members: [GroupChatMember] = []
    @State private var isLoadingMembers = true
    @State private var showingAddMembers = false
    @State private var showingAllMembers = false
    @State private var showingLeaveConfirm = false
    @State private var showingDeleteConfirm = false
    @State private var errorMessage: String?
    @State private var isProcessing = false

    private var isAdmin: Bool {
        members.first(where: { $0.userId == currentUserId })?.role == .admin
    }

    private var isSessionLinked: Bool { groupChat.gameId != nil }
    private let previewMemberCount = 5

    // Stable color from name for initials avatar
    private var avatarColor: Color {
        let colors: [Color] = [
            .stackGreen, .blue, .purple, .orange, .pink,
            Color(.systemTeal), Color(.systemIndigo),
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
        ScrollView {
            VStack(spacing: 0) {
                // Header: Avatar + Name + Subtitle
                VStack(spacing: 10) {
                    // Avatar
                    communityAvatar
                        .padding(.top, 20)

                    Text(groupChat.name)
                        .font(.system(size: 22, weight: .bold))

                    Text("Community · \(members.count) members")
                        .font(.system(size: 14))
                        .foregroundColor(.stackSecondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 20)

                // Action buttons row
                actionButtonsRow
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)

                // Session link
                if isSessionLinked {
                    sectionCard {
                        Button {
                            appState.pendingGroupChatId = nil
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                appState.selectedTab = 1
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 17))
                                    .foregroundColor(.stackGreen)
                                    .frame(width: 28)
                                Text("View Session")
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(.tertiaryLabel))
                            }
                            .padding(14)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }

                // Members preview
                membersSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                // Danger zone
                dangerSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Community Info")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isAdmin {
                    Button("Edit") {
                        // Future: rename community
                    }
                    .foregroundColor(.stackGreen)
                }
            }
        }
        .task {
            await loadMembers()
        }
        .alert("Leave Community?", isPresented: $showingLeaveConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Leave", role: .destructive) {
                Task { await leaveChat() }
            }
        } message: {
            Text("You will be removed from this community.")
        }
        .alert("Delete Community?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await deleteChat() }
            }
        } message: {
            Text("This will permanently delete this community for all members.")
        }
        .sheet(isPresented: $showingAddMembers) {
            AddMembersSheet(groupChatId: groupChat.id, existingMemberIds: Set(members.map(\.userId))) {
                await loadMembers()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Community Avatar

    @ViewBuilder
    private var communityAvatar: some View {
        if let avatarUrl = groupChat.avatarUrl, let url = URL(string: avatarUrl) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                initialsAvatar
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
        } else if let firstUrl = groupChat.memberAvatarUrls?.first, let url = URL(string: firstUrl) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                initialsAvatar
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
        } else {
            initialsAvatar
        }
    }

    private var initialsAvatar: some View {
        Text(initials)
            .font(.system(size: 36, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 100, height: 100)
            .background(Circle().fill(avatarColor.opacity(0.8)))
    }

    // MARK: - Action Buttons Row

    private var actionButtonsRow: some View {
        HStack(spacing: 12) {
            if isAdmin {
                actionButton(icon: "person.badge.plus", label: "Add") {
                    showingAddMembers = true
                }
            }

            if isSessionLinked {
                actionButton(icon: "calendar", label: "Session") {
                    appState.pendingGroupChatId = nil
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        appState.selectedTab = 1
                    }
                }
            }

            actionButton(icon: "magnifyingglass", label: "Search") {
                // Future: search messages
            }
        }
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.stackGreen)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.stackGreen)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Members Section

    private var membersSection: some View {
        sectionCard {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("\(members.count) Members")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.stackSecondaryText)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 8)

                if isLoadingMembers {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    // Preview members (capped)
                    let previewMembers = Array(members.prefix(previewMemberCount))
                    ForEach(previewMembers) { member in
                        memberRow(member)
                        if member.id != previewMembers.last?.id {
                            Divider()
                                .padding(.leading, 66)
                        }
                    }

                    // "See all" button
                    if members.count > previewMemberCount {
                        Divider()
                            .padding(.leading, 14)

                        NavigationLink {
                            AllMembersView(
                                groupChat: groupChat,
                                members: members,
                                currentUserId: currentUserId,
                                isAdmin: isAdmin,
                                onMembersChanged: { await loadMembers() }
                            )
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.2")
                                    .font(.system(size: 16))
                                    .foregroundColor(.stackGreen)
                                    .frame(width: 40, height: 40)
                                    .background(Color.stackGreen.opacity(0.1))
                                    .clipShape(Circle())

                                Text("See all members")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.stackGreen)

                                Spacer()

                                Text("\(members.count)")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(.tertiaryLabel))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(.tertiaryLabel))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                    }
                }
            }
            .padding(.bottom, 4)
        }
    }

    private func memberRow(_ member: GroupChatMember) -> some View {
        HStack(spacing: 12) {
            if let avatarUrl = member.users.avatarUrl, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    memberPlaceholder
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                memberPlaceholder
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)

                    if member.userId == currentUserId {
                        Text("You")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.stackSecondaryText)
                    }
                }

                if member.role == .admin {
                    Text("Admin")
                        .font(.system(size: 12))
                        .foregroundColor(.stackGreen)
                } else if let rating = member.users.duprRating {
                    Text("DUPR \(String(format: "%.1f", rating))")
                        .font(.system(size: 12))
                        .foregroundColor(.stackSecondaryText)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var memberPlaceholder: some View {
        Circle()
            .fill(Color.gray.opacity(0.25))
            .frame(width: 40, height: 40)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            )
    }

    // MARK: - Danger Section

    private var dangerSection: some View {
        sectionCard {
            VStack(spacing: 0) {
                Button {
                    showingLeaveConfirm = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16))
                            .foregroundColor(.red)
                            .frame(width: 28)
                        Text("Leave Community")
                            .font(.system(size: 16))
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding(14)
                }
                .disabled(isProcessing)

                if isAdmin && !isSessionLinked {
                    Divider()
                        .padding(.leading, 54)

                    Button {
                        showingDeleteConfirm = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "trash")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                                .frame(width: 28)
                            Text("Delete Community")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(14)
                    }
                    .disabled(isProcessing)
                }
            }
        }
    }

    // MARK: - Section Card

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Data

    private func loadMembers() async {
        do {
            members = try await GroupChatService.members(groupChatId: groupChat.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingMembers = false
    }

    private func leaveChat() async {
        isProcessing = true
        do {
            try await GroupChatService.leaveGroupChat(groupChatId: groupChat.id)
            dismiss()
            onLeave()
        } catch {
            errorMessage = error.localizedDescription
        }
        isProcessing = false
    }

    private func deleteChat() async {
        isProcessing = true
        do {
            try await GroupChatService.deleteGroupChat(groupChatId: groupChat.id)
            dismiss()
            onDelete()
        } catch {
            errorMessage = error.localizedDescription
        }
        isProcessing = false
    }
}
