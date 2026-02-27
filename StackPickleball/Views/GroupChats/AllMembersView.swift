import SwiftUI

struct AllMembersView: View {
    let groupChat: GroupChat
    let members: [GroupChatMember]
    let currentUserId: UUID
    let isAdmin: Bool
    var onMembersChanged: (() async -> Void)?

    @State private var showingRemoveConfirm: GroupChatMember?
    @State private var errorMessage: String?
    @State private var removedIds: Set<UUID> = []

    private var visibleMembers: [GroupChatMember] {
        members.filter { !removedIds.contains($0.id) }
    }

    var body: some View {
        List {
            Section {
                ForEach(visibleMembers) { member in
                    HStack(spacing: 12) {
                        if let avatarUrl = member.users.avatarUrl, let url = URL(string: avatarUrl) {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                memberPlaceholder
                            }
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                        } else {
                            memberPlaceholder
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(member.displayName)
                                    .font(.system(size: 15, weight: .medium))

                                if member.userId == currentUserId {
                                    Text("You")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.stackSecondaryText)
                                }
                            }

                            HStack(spacing: 8) {
                                if member.role == .admin {
                                    Text("Admin")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.stackGreen)
                                }
                                if let rating = member.users.duprRating {
                                    Text("DUPR \(String(format: "%.1f", rating))")
                                        .font(.system(size: 12))
                                        .foregroundColor(.stackSecondaryText)
                                }
                            }
                        }

                        Spacer()

                        if isAdmin && member.userId != currentUserId {
                            Button {
                                showingRemoveConfirm = member
                            } label: {
                                Image(systemName: "person.badge.minus")
                                    .font(.system(size: 14))
                                    .foregroundColor(.red.opacity(0.6))
                                    .frame(width: 32, height: 32)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("\(visibleMembers.count) members")
                    .font(.system(size: 13))
                    .foregroundColor(.stackSecondaryText)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Members")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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
            Text("This member will be removed from the community.")
        }
        .errorAlert($errorMessage)
    }

    private var memberPlaceholder: some View {
        Circle()
            .fill(Color.gray.opacity(0.25))
            .frame(width: 44, height: 44)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 17))
                    .foregroundColor(.white)
            )
    }

    private func removeMember(_ member: GroupChatMember) async {
        do {
            try await GroupChatService.removeMember(groupChatId: groupChat.id, userId: member.userId)
            removedIds.insert(member.id)
            await onMembersChanged?()
        } catch {
            errorMessage = error.localizedDescription
        }
        showingRemoveConfirm = nil
    }
}
