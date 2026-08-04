import SwiftUI

// Match history is not yet backed by the database — placeholder for future use
struct MatchHistoryRow: View {
    let label: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.stackGreen.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "sportscourt")
                        .font(.system(size: 18))
                        .foregroundColor(.stackGreen)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(AppFonts.body())
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(detail)
                    .font(AppFonts.callout())
                    .foregroundColor(.stackSecondaryText)
            }

            Spacer()
        }
        .padding(AppConstants.cardPadding)
    }
}

#Preview {
    MatchHistoryRow(label: "Coming Soon", detail: "Match history will appear here")
        .background(Color.white)
        .padding(16)
        .background(Color.stackBackground)
}
