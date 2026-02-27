import SwiftUI

struct AvailablePlayerCard: View {
    let player: AvailablePlayer
    var isExpanded: Bool = false
    var isFriend: Bool = false
    var isRequestSent: Bool = false
    var onTap: (() -> Void)?
    var onInviteTapped: (() -> Void)?
    var onAddFriendTapped: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Avatar with green dot
                ZStack(alignment: .bottomTrailing) {
                    if let urlStr = player.avatarUrl, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            initialCircle
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                    } else {
                        initialCircle
                    }

                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }

                // Name, note, metadata
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(player.displayName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        if let rating = player.duprRating {
                            Text("\(String(format: "%.1f", rating)) DUPR")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.stackDUPRBadge)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.stackBadgeBg)
                                .cornerRadius(4)
                        }
                    }

                    if let format = player.preferredFormat {
                        Text(format.displayName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(format.accentColor)
                            .cornerRadius(6)
                    }

                    if let note = player.note, !note.isEmpty {
                        Text(note)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.stackSecondaryText)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(16)

            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)

                HStack(spacing: 10) {
                    Button {
                        onInviteTapped?()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 13))
                            Text("Invite to Session")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.stackGreen)
                        .cornerRadius(10)
                    }

                    if !isFriend {
                        Button {
                            onAddFriendTapped?()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isRequestSent ? "checkmark" : "person.badge.plus")
                                    .font(.system(size: 13))
                                Text(isRequestSent ? "Request Sent" : "Add Friend")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(isRequestSent ? .stackSecondaryText : .stackGreen)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isRequestSent ? Color(.systemGray5) : Color.stackGreen.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .disabled(isRequestSent)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(Color.stackCardWhite)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }

    private var initialCircle: some View {
        Circle()
            .fill(Color.stackGreen.opacity(0.15))
            .frame(width: 48, height: 48)
            .overlay(
                Text(playerInitial)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.stackGreen)
            )
    }

    private var playerInitial: String {
        let name = player.firstName ?? player.username ?? "?"
        return String(name.prefix(1)).uppercased()
    }
}
