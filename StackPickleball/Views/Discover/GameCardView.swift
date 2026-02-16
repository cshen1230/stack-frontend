import SwiftUI

struct GameCardView: View {
    let game: Game
    let onJoin: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Creator avatar placeholder
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                )

            // Game details
            VStack(alignment: .leading, spacing: 6) {
                // Name + badge
                HStack(spacing: 8) {
                    Text(game.creatorDisplayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)

                    Text(game.gameFormat.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.stackGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.stackBadgeBg)
                        .cornerRadius(8)
                }

                // Time row
                HStack(spacing: 0) {
                    Text(game.gameDatetime, style: .time)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                    Text(" \u{2022} ")
                        .font(.system(size: 16))
                        .foregroundColor(.stackSecondaryText)
                    Text(game.gameDatetime, style: .date)
                        .font(.system(size: 16))
                        .foregroundColor(.stackSecondaryText)
                }

                // Location row
                if let location = game.locationName {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle")
                            .font(.system(size: 13))
                            .foregroundColor(.stackGreen)
                        Text(location)
                            .font(.system(size: 14))
                            .foregroundColor(.black)
                    }
                }

                // DUPR row
                if let min = game.skillLevelMin, let max = game.skillLevelMax {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy")
                            .font(.system(size: 13))
                            .foregroundColor(.stackGreen)
                        Text("DUPR \(String(format: "%.1f", min))-\(String(format: "%.1f", max))")
                            .font(.system(size: 14))
                            .foregroundColor(.black)
                    }
                }

                // Spots row
                HStack(spacing: 4) {
                    Image(systemName: "person.2")
                        .font(.system(size: 13))
                        .foregroundColor(.stackGreen)
                    Text("\(game.spotsFilled)/\(game.spotsAvailable) spots")
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                }
            }

            Spacer()

            // Join button
            if game.spotsRemaining > 0 {
                Button(action: onJoin) {
                    Text("Join")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.stackGreen)
                        .cornerRadius(10)
                }
            } else {
                Text("Full")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.stackSecondaryText)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
            }
        }
        .padding(16)
        .background(Color.stackCardWhite)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black, lineWidth: 1)
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(game.gameFormat.accentColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.black, lineWidth: 1)
                )
                .offset(x: 3, y: 4)
        )
    }
}
