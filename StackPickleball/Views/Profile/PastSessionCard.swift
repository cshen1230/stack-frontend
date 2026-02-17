import SwiftUI

struct PastSessionCard: View {
    let game: Game
    let isHost: Bool

    var body: some View {
        HStack(spacing: 14) {
            // Creator avatar with crown overlay for host
            ZStack(alignment: .top) {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    )

                if isHost {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                        .offset(y: -8)
                }
            }

            // Game details
            VStack(alignment: .leading, spacing: 2) {
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

                    if isHost {
                        Text("Host")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.orange)
                            .cornerRadius(6)
                    }
                }

                // Date
                (Text(game.gameDatetime, format: .dateTime.month(.abbreviated).day().year())
                + Text("  ·  ")
                + Text(game.gameDatetime, format: .dateTime.hour().minute()))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.stackSecondaryText)
                    .padding(.bottom, 6)

                VStack(alignment: .leading, spacing: 3) {
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

                    HStack(spacing: 5) {
                        Image(systemName: "person.2")
                            .font(.system(size: 11))
                            .foregroundColor(.stackSecondaryText)
                        Text("\(game.spotsFilled)/\(game.spotsAvailable) players")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
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
                .fill(game.gameFormat.accentColor.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.black, lineWidth: 1)
                )
                .offset(x: 3, y: 4)
        )
    }
}
