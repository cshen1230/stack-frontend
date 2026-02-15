import SwiftUI

struct MatchHistoryRow: View {
    let match: MatchHistoryItem

    private var isWin: Bool { match.result == .win }

    var body: some View {
        HStack(spacing: 14) {
            // Win/Loss indicator
            Circle()
                .fill(isWin ? Color.stackWinGreen : Color.stackLossRed)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: isWin ? "checkmark" : "xmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isWin ? .stackWinIcon : .stackLossIcon)
                )

            // Match details
            VStack(alignment: .leading, spacing: 4) {
                Text("vs \(match.opponents)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)

                Text(match.score)
                    .font(.system(size: 15))
                    .foregroundColor(.black)

                HStack(spacing: 4) {
                    Text(match.date, format: .dateTime.month(.abbreviated).day().year())
                        .font(.system(size: 13))
                        .foregroundColor(.stackTimestamp)

                    Text("\u{2022}")
                        .font(.system(size: 13))
                        .foregroundColor(.stackTimestamp)

                    Image(systemName: "mappin.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.stackTimestamp)

                    Text(match.location)
                        .font(.system(size: 13))
                        .foregroundColor(.stackTimestamp)
                }
            }

            Spacer()
        }
        .padding(16)
    }
}

#Preview {
    VStack(spacing: 0) {
        MatchHistoryRow(match: MatchHistoryItem(
            id: UUID(),
            opponents: "Sarah J. & Mike C.",
            score: "11-9, 11-7",
            result: .win,
            date: Date().addingTimeInterval(-86400),
            location: "Sunset Park"
        ))

        Divider()
            .padding(.leading, 72)

        MatchHistoryRow(match: MatchHistoryItem(
            id: UUID(),
            opponents: "Tom A. & Lisa K.",
            score: "8-11, 11-9, 9-11",
            result: .loss,
            date: Date().addingTimeInterval(-7 * 86400),
            location: "Riverside Park"
        ))
    }
    .background(Color.white)
    .cornerRadius(16)
    .padding(16)
    .background(Color.stackBackground)
}
