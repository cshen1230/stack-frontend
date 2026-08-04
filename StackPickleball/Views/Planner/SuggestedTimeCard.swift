import SwiftUI

/// Tappable banner that says "You usually play Thursdays at 6 PM" and offers to
/// jump the planner to that slot. Visual language borrowed from Asana: white card,
/// thin accent bar on the leading edge, neutral text, minimal chrome.
struct SuggestedTimeCard: View {
    let suggestion: SuggestedPlayTime
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Asana-style colored accent bar on the leading edge.
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.stackGreen)
                    .frame(width: 4)
                    .padding(.vertical, 4)

                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.stackGreen)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("You usually play \(suggestion.weekdayName)s at \(suggestion.hourLabel)")
                            .font(AppFonts.subheadline())
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text("Played \(suggestion.playCount) times")
                            .font(AppFonts.caption2())
                            .foregroundColor(.secondary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(.tertiaryLabel))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color(.separator).opacity(0.4), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        }
        .buttonStyle(.pressableSubtle)
        .contentShape(RoundedRectangle(cornerRadius: 10))
    }
}
