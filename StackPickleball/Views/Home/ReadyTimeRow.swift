import SwiftUI

/// One friend's ready-to-play window today, led by the time it starts, so the section reads
/// as a timeline of who is around when.
struct ReadyTimeRow: View {
    let friend: ReadyFriend
    /// Passed in rather than read from the clock so the row flips from "1:45 PM" to "Now"
    /// when that time arrives, instead of only on the next reload.
    var now: Date = Date()
    var onTap: () -> Void

    private var isNow: Bool { friend.isActive(at: now) }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                timeColumn

                avatar

                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.firstName ?? friend.username ?? "Unknown")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.stackSecondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if let format = friend.preferredFormat {
                    Text(format.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(format.accentColor)
                        .cornerRadius(6)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var timeColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(friend.startLabel(at: now))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isNow ? .stackGreen : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if isNow {
                Circle()
                    .fill(Color.stackGreen)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: 62, alignment: .leading)
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .stroke(isNow ? Color.stackGreen : Color.stackBorder, lineWidth: 2)
                .frame(width: 44, height: 44)

            if let urlStr = friend.avatarUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initialCircle
                }
                .frame(width: 38, height: 38)
                .clipShape(Circle())
            } else {
                initialCircle
            }
        }
        // An upcoming window is real but not actionable yet — let it sit back a little.
        .opacity(isNow ? 1 : 0.75)
    }

    private var initialCircle: some View {
        Circle()
            .fill(isNow ? Color.stackGreen : Color.stackSecondaryText)
            .frame(width: 38, height: 38)
            .overlay(
                Text(friendInitial)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
            )
    }

    private var friendInitial: String {
        let name = friend.firstName ?? friend.username ?? "?"
        return String(name.prefix(1)).uppercased()
    }

    private var subtitle: String {
        let window = isNow ? "until \(friend.endLabel)" : friend.windowLabel(at: now)
        if let note = friend.note, !note.isEmpty {
            return "\(window) · \(note)"
        }
        return window
    }
}
