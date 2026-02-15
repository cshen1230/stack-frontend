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
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundColor(.stackSecondaryText)
            }

            Spacer()
        }
        .padding(16)
    }
}

#Preview {
    MatchHistoryRow(label: "Coming Soon", detail: "Match history will appear here")
        .background(Color.white)
        .padding(16)
        .background(Color.stackBackground)
}
