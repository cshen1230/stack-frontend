import SwiftUI

struct GameCardView: View {
    let game: Game
    let isHost: Bool
    let isJoined: Bool
    let onJoin: () -> Void
    let onView: () -> Void

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

            // Action buttons
            VStack(spacing: 6) {
                // View button — always shown so anyone can see participants
                Button(action: onView) {
                    Text("View")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.stackGreen)
                        .frame(width: 70)
                        .padding(.vertical, 8)
                        .background(Color.stackGreen.opacity(0.15))
                        .cornerRadius(8)
                }

                // Join button — only for users who haven't joined yet
                if !isJoined {
                    if game.spotsRemaining > 0 {
                        Button(action: onJoin) {
                            Text("Join")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 70)
                                .padding(.vertical, 8)
                                .background(Color.stackGreen)
                                .cornerRadius(8)
                        }
                    } else {
                        Text("Full")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.stackSecondaryText)
                            .frame(width: 70)
                            .padding(.vertical, 8)
                    }
                }
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
