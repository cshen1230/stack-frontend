import SwiftUI

/// Opened by tapping someone's band on the calendar. Everything here is what you'd want to
/// know before dragging a slot over their window.
struct FriendAvailabilitySheet: View {
    let slot: FriendAvailability

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.stackSecondaryText.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            AvatarCircle(urlString: slot.avatarUrl, name: slot.displayName, size: 80)
                .overlay(Circle().stroke(Color.stackGreen, lineWidth: 3).frame(width: 86, height: 86))

            VStack(spacing: 6) {
                Text(slot.displayName)
                    .font(AppFonts.headline())
                    .fontWeight(.bold)

                if let rating = slot.duprRating {
                    HStack(spacing: 3) {
                        if slot.isDuprConnected {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.stackDUPRBadge)
                        }
                        Text("\(String(format: "%.1f", rating)) DUPR")
                            .font(AppFonts.subheadline())
                            .fontWeight(.semibold)
                            .foregroundColor(.stackDUPRBadge)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.stackBadgeBg)
                    .cornerRadius(6)
                }
            }

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 13))
                Text("Usually plays \(slot.timeRangeLabel)")
                    .font(AppFonts.body())
                    .fontWeight(.medium)
            }
            .foregroundColor(.stackSecondaryText)

            if let format = slot.preferredFormat {
                Text(format.displayName)
                    .font(AppFonts.caption())
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(format.accentColor)
                    .cornerRadius(8)
            }

            Text("Drag across their window on the calendar to plan a session and invite them.")
                .font(AppFonts.callout())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.stackBackground)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }
}
