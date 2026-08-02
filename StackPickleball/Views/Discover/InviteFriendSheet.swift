import SwiftUI

struct InviteFriendSheet: View {
    let game: Game
    @Environment(\.dismiss) private var dismiss
    @State private var friends: [FriendRow] = []
    @State private var isLoading = true
    @State private var invitedIds: Set<UUID> = []
    @State private var errorMessage: String?

    // SMS invite state
    @State private var smsInvitations: [SMSInvitation] = []
    @State private var smsName = ""
    @State private var smsPhone = ""
    @State private var isSendingSMS = false
    /// Needed to decide whose phone numbers this viewer is allowed to see.
    @State private var currentUserId: UUID?

    var body: some View {
        NavigationStack {
            List {
                // ── Friends section ────────────────────────
                if isLoading {
                    Section {
                        SkeletonList(count: 3) { SkeletonRow(showsTrailing: true) }
                    }
                } else if !friends.isEmpty {
                    Section("Friends") {
                        ForEach(friends) { friend in
                            HStack(spacing: 12) {
                                avatarImage(url: friend.avatarUrl, size: 40)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(friend.displayName)
                                        .font(.system(size: 15, weight: .semibold))
                                    if let dupr = friend.duprRating {
                                        HStack(spacing: 3) {
                                            if friend.isDuprConnected {
                                                Image(systemName: "checkmark.seal.fill")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.stackGreen)
                                            }
                                            Text("DUPR \(String(format: "%.1f", dupr))")
                                                .font(.system(size: 13))
                                                .foregroundColor(.stackGreen)
                                        }
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
                    }
                }

                // ── Invite via Text section ────────────────
                Section("Invite via Text") {
                    TextField("Name", text: $smsName)
                        .font(.system(size: 15))
                        .textContentType(.name)
                        .autocorrectionDisabled()

                    TextField("Phone number", text: $smsPhone)
                        .font(.system(size: 15))
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)

                    Button {
                        Task { await sendSMSInvite() }
                    } label: {
                        HStack(spacing: 8) {
                            if isSendingSMS {
                                ProgressView().controlSize(.small)
                            }
                            Text("Send Text Invite")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(smsFieldsValid ? Color.stackGreen : Color.gray.opacity(0.4))
                        .cornerRadius(8)
                    }
                    .disabled(!smsFieldsValid || isSendingSMS)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                // ── Sent SMS invites ───────────────────────
                if !smsInvitations.isEmpty {
                    Section("Text Invites") {
                        ForEach(smsInvitations) { inv in
                            HStack(spacing: 12) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.stackGreen)
                                    .frame(width: 40, height: 40)
                                    .background(Color.stackGreen.opacity(0.15))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(inv.inviteeName)
                                        .font(.system(size: 15, weight: .semibold))
                                    if let phone = inv.displayPhoneNumber(viewerId: currentUserId) {
                                        Text(phone)
                                            .font(.system(size: 12))
                                            .foregroundColor(.stackSecondaryText)
                                    } else {
                                        Text("Invited by text")
                                            .font(.system(size: 12))
                                            .foregroundColor(.stackSecondaryText)
                                    }
                                }

                                Spacer()

                                smsStatusBadge(inv.rsvpStatus)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
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
                currentUserId = await AuthService.currentUserId()
                async let loadF: Void = loadFriends()
                async let loadS: Void = loadSMSInvitations()
                _ = await (loadF, loadS)
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
            errorMessage = error.userFacingMessage
        }
        isLoading = false
    }

    private func invite(_ friend: FriendRow) async {
        invitedIds.insert(friend.friendUserId)
        do {
            try await FriendService.inviteToGame(gameId: game.id, friendId: friend.friendUserId)
        } catch {
            invitedIds.remove(friend.friendUserId)
            errorMessage = error.userFacingMessage
        }
    }

    // MARK: - SMS

    private var smsFieldsValid: Bool {
        !smsName.trimmingCharacters(in: .whitespaces).isEmpty
            && SMSInviteEntry.looksLikeAPhoneNumber(smsPhone)
    }

    private func loadSMSInvitations() async {
        do {
            smsInvitations = try await SMSInviteService.smsInvitations(gameId: game.id)
        } catch {
            // non-critical
        }
    }

    private func sendSMSInvite() async {
        isSendingSMS = true
        defer { isSendingSMS = false }
        do {
            try await SMSInviteService.sendSMSInvite(
                gameId: game.id,
                inviteeName: smsName.trimmingCharacters(in: .whitespaces),
                phoneNumber: smsPhone
            )
            smsName = ""
            smsPhone = ""
            await loadSMSInvitations()
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func smsStatusBadge(_ status: SMSRSVPStatus) -> some View {
        let (label, color): (String, Color) = {
            switch status {
            case .pending: return ("Pending", .orange)
            case .accepted: return ("Accepted", .stackGreen)
            case .declined: return ("Declined", .red)
            case .cancelled: return ("Cancelled", .gray)
            }
        }()
        return Text(label)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .cornerRadius(6)
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
