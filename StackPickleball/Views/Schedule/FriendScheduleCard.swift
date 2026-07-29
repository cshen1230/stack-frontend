import SwiftUI

struct FriendScheduleCard: View {
    let schedule: FriendScheduleRow

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            if let urlStr = schedule.avatarUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initialCircle
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                initialCircle
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(schedule.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if let rating = schedule.duprRating {
                        HStack(spacing: 3) {
                            if schedule.isDuprConnected {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.stackDUPRBadge)
                            }
                            Text("\(String(format: "%.1f", rating))")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.stackDUPRBadge)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.stackBadgeBg)
                        .cornerRadius(4)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundColor(.stackSecondaryText)
                    Text(schedule.formattedTimeRange)
                        .font(.system(size: 13))
                        .foregroundColor(.stackSecondaryText)
                }
            }

            Spacer(minLength: 0)

            if let format = schedule.preferredFormat {
                Text(format.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(format.accentColor)
                    .cornerRadius(6)
            }
        }
        .padding(12)
        .background(Color.stackCardWhite)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.stackBorder, lineWidth: 1)
        )
    }

    private var initialCircle: some View {
        Circle()
            .fill(Color.stackGreen.opacity(0.15))
            .frame(width: 40, height: 40)
            .overlay(
                Text(String((schedule.firstName ?? schedule.username ?? "?").prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.stackGreen)
            )
    }
}
