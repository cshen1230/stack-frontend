import SwiftUI

struct GroupChatSettingsSheet: View {
    let groupChat: GroupChat
    let currentUserId: UUID
    let onLeave: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var members: [GroupChatMember] = []
    @State private var isLoadingMembers = true
    @State private var showingAddMembers = false
    @State private var showingLeaveConfirm = false
    @State private var showingDeleteConfirm = false
    @State private var showingRemoveConfirm: GroupChatMember?
    @State private var errorMessage: String?
    @State private var isProcessing = false

    private var isAdmin: Bool {
        members.first(where: { $0.userId == currentUserId })?.role == .admin
    }

    private var isSessionLinked: Bool { groupChat.gameId != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Group info
                    VStack(spacing: 6) {
                        Text(groupChat.name)
                            .font(.system(size: 20, weight: .bold))

                        if isSessionLinked {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 12))
                                Text("Linked to a session")
                            }
                            .font(.system(size: 13))
                            .foregroundColor(.stackSecondaryText)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    // View Session button (for session-linked chats)
                    if let gameId = groupChat.gameId {
                        Button {
                            appState.pendingGroupChatId = nil
                            dismiss()
                            // Navigate to session via deep link mechanism
                            // Use a small delay to let the sheet dismiss
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                appState.selectedTab = 1
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 15))
                                    .foregroundColor(.stackGreen)
                                Text("View Session")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(14)
                            .background(Color.stackCardWhite)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.stackGreen.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 16)
                    }

                    // Members section
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Members (\(members.count))")
                                .font(.system(size: 16, weight: .bold))
                                .padding(.horizontal, 4)

                            Spacer()

                            if isAdmin {
                                Button {
                                    showingAddMembers = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "person.badge.plus")
                                            .font(.system(size: 13))
                                        Text("Add")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundColor(.stackGreen)
                                }
                            }
                        }

                        if isLoadingMembers {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        } else {
                            ForEach(members) { member in
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

                                            if member.role == .admin {
                                                HStack(spacing: 2) {
                                                    Image(systemName: "crown.fill")
                                                        .font(.system(size: 9))
                                                    Text("Admin")
                                                        .font(.system(size: 10, weight: .semibold))
                                                }
                                                .foregroundColor(.orange)
                                            }
                                        }

                                        if let rating = member.users.duprRating {
                                            Text("DUPR \(String(format: "%.1f", rating))")
                                                .font(.system(size: 12))
                                                .foregroundColor(.stackGreen)
                                        }
                                    }

                                    Spacer()

                                    if isAdmin && member.userId != currentUserId {
                                        Button(role: .destructive) {
                                            showingRemoveConfirm = member
                                        } label: {
                                            Image(systemName: "person.badge.minus")
                                                .font(.system(size: 14))
                                                .foregroundColor(.red.opacity(0.7))
                                                .frame(width: 32, height: 32)
                                        }
                                    }
                                }
                                .padding(10)
                                .background(Color.stackCardWhite)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.stackBorder, lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // Actions
                    VStack(spacing: 10) {
                        Button {
                            showingLeaveConfirm = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 15))
                                Text("Leave Group Chat")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .disabled(isProcessing)

                        if isAdmin && !isSessionLinked {
                            Button {
                                showingDeleteConfirm = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 15))
                                    Text("Delete Group Chat")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .disabled(isProcessing)
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
                .padding(.bottom, 24)
            }
            .background(Color.stackBackground)
            .navigationTitle("Chat Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadMembers()
            }
            .alert("Leave Group Chat?", isPresented: $showingLeaveConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Leave", role: .destructive) {
                    Task { await leaveChat() }
                }
            } message: {
                Text("You will be removed from this group chat.")
            }
            .alert("Delete Group Chat?", isPresented: $showingDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task { await deleteChat() }
                }
            } message: {
                Text("This will permanently delete the group chat for all members.")
            }
            .alert(
                "Remove \(showingRemoveConfirm?.displayName ?? "")?",
                isPresented: Binding(
                    get: { showingRemoveConfirm != nil },
                    set: { if !$0 { showingRemoveConfirm = nil } }
                )
            ) {
                Button("Cancel", role: .cancel) { showingRemoveConfirm = nil }
                Button("Remove", role: .destructive) {
                    if let member = showingRemoveConfirm {
                        Task { await removeMember(member) }
                    }
                }
            } message: {
                Text("This member will be removed from the group chat.")
            }
            .sheet(isPresented: $showingAddMembers) {
                AddMembersSheet(groupChatId: groupChat.id, existingMemberIds: Set(members.map(\.userId))) {
                    await loadMembers()
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var memberPlaceholder: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 40, height: 40)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            )
    }

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

    private func removeMember(_ member: GroupChatMember) async {
        isProcessing = true
        do {
            try await GroupChatService.removeMember(groupChatId: groupChat.id, userId: member.userId)
            members.removeAll { $0.id == member.id }
        } catch {
            errorMessage = error.localizedDescription
        }
        showingRemoveConfirm = nil
        isProcessing = false
    }
}
