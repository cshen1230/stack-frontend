import SwiftUI

struct ReadyFriendDetailSheet: View {
    let friend: ReadyFriend
    var onCreateGame: () -> Void
    var onInviteToGame: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            // Drag indicator
            Capsule()
                .fill(Color.stackSecondaryText.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            // Large avatar
            ZStack {
                Circle()
                    .stroke(Color.stackGreen, lineWidth: 3)
                    .frame(width: 86, height: 86)

                if let urlStr = friend.avatarUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        initialCircle
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                } else {
                    initialCircle
                }
            }

            // Name + DUPR badge
            VStack(spacing: 6) {
                Text(friend.displayName)
                    .font(.system(size: 20, weight: .bold))

                if let rating = friend.duprRating {
                    HStack(spacing: 3) {
                        if friend.isDuprConnected {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.stackDUPRBadge)
                        }
                        Text("\(String(format: "%.1f", rating)) DUPR")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.stackDUPRBadge)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.stackBadgeBg)
                    .cornerRadius(6)
                }
            }

            // Time window
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 13))
                    .foregroundColor(.stackSecondaryText)
                Text(timeWindowText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.stackSecondaryText)
            }

            // Format badge
            if let format = friend.preferredFormat {
                Text(format.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(format.accentColor)
                    .cornerRadius(8)
            }

            // Note
            if let note = friend.note, !note.isEmpty {
                Text("\"\(note)\"")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .italic()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            // Action buttons
            VStack(spacing: 10) {
                Button(action: {
                    dismiss()
                    onCreateGame()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 15))
                        Text("Create Game")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.stackGreen)
                    .cornerRadius(12)
                }

                Button(action: {
                    dismiss()
                    onInviteToGame()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 15))
                        Text("Invite to Game")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.stackGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.stackGreen.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.stackGreen.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(Color.stackBackground)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    private var timeWindowText: String {
        friend.windowLabel()
    }

    private var initialCircle: some View {
        Circle()
            .fill(Color.stackGreen)
            .frame(width: 80, height: 80)
            .overlay(
                Text(friendInitial)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
            )
    }

    private var friendInitial: String {
        let name = friend.firstName ?? friend.username ?? "?"
        return String(name.prefix(1)).uppercased()
    }
}
