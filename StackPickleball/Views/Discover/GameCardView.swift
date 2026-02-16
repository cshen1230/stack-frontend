import SwiftUI

struct GameCardView: View {
    let game: Game
    let onJoin: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Creator avatar
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                )

            // Game details
            VStack(alignment: .leading, spacing: 2) {
                // Host name + format badge
                HStack(spacing: 8) {
                    Text(game.creatorDisplayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(game.gameFormat.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.stackGreen)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.stackBadgeBg)
                        .cornerRadius(6)
                }

                // Time · Date
                (Text(game.gameDatetime, format: .dateTime.hour().minute())
                + Text("  ·  ")
                + Text(game.gameDatetime, format: .dateTime.month(.abbreviated).day()))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.stackSecondaryText)
                    .padding(.bottom, 6)

                // Metadata
                VStack(alignment: .leading, spacing: 3) {
                    // Location
                    if let location = game.locationName {
                        HStack(spacing: 5) {
                            Image(systemName: "mappin")
                                .font(.system(size: 11))
                                .foregroundColor(.stackSecondaryText)
                            Text(location)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }

                    // DUPR
                    if let min = game.skillLevelMin, let max = game.skillLevelMax {
                        HStack(spacing: 5) {
                            Image(systemName: "trophy")
                                .font(.system(size: 11))
                                .foregroundColor(.stackSecondaryText)
                            Text("DUPR \(String(format: "%.1f", min))–\(String(format: "%.1f", max))")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Spots
                    HStack(spacing: 5) {
                        Image(systemName: "person.2")
                            .font(.system(size: 11))
                            .foregroundColor(.stackSecondaryText)
                        Text("\(game.spotsFilled)/\(game.spotsAvailable) spots")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
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
