import SwiftUI

struct ReadyFriendCard: View {
    let friend: ReadyFriend
    var isExpanded: Bool = false
    var onTap: (() -> Void)?
    var onCreateGame: (() -> Void)?
    var onInviteToGame: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Avatar with pulsing green dot
                ZStack(alignment: .bottomTrailing) {
                    if let urlStr = friend.avatarUrl, let url = URL(string: urlStr) {
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

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(friend.displayName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        if let rating = friend.duprRating {
                            HStack(spacing: 3) {
                                if friend.isDuprConnected {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.stackDUPRBadge)
                                }
                                Text("\(String(format: "%.1f", rating)) DUPR")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.stackDUPRBadge)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.stackBadgeBg)
                            .cornerRadius(4)
                        }
                    }

                    // Time window
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                            .foregroundColor(.stackSecondaryText)
                        Text(timeWindowText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.stackSecondaryText)
                    }

                    if let format = friend.preferredFormat {
                        Text(format.displayName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(format.accentColor)
                            .cornerRadius(6)
                    }

                    if let note = friend.note, !note.isEmpty {
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
                        onCreateGame?()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 13))
                            Text("Create Game")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.stackGreen)
                        .cornerRadius(10)
                    }

                    Button {
                        onInviteToGame?()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 13))
                            Text("Invite to Game")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.stackGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.stackGreen.opacity(0.1))
                        .cornerRadius(10)
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

    private var timeWindowText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let untilStr = formatter.string(from: friend.availableUntil)
        if let from = friend.availableFrom {
            let fromStr = formatter.string(from: from)
            return "\(fromStr) – \(untilStr)"
        }
        return "until \(untilStr)"
    }

    private var initialCircle: some View {
        Circle()
            .fill(Color.stackGreen.opacity(0.15))
            .frame(width: 48, height: 48)
            .overlay(
                Text(friendInitial)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.stackGreen)
            )
    }

    private var friendInitial: String {
        let name = friend.firstName ?? friend.username ?? "?"
        return String(name.prefix(1)).uppercased()
    }
}
