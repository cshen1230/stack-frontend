import SwiftUI

/// Tappable banner that says "You usually play Thursdays at 6 PM" and offers to
/// jump the planner to that slot.
struct SuggestedTimeCard: View {
    let suggestion: SuggestedPlayTime
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.stackGreen)

                VStack(alignment: .leading, spacing: 2) {
                    Text("You usually play \(suggestion.weekdayName)s at \(suggestion.hourLabel)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("Played \(suggestion.playCount) times")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.stackSecondaryText)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.stackSecondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.stackGreen.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.stackGreen.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
