import SwiftUI

struct GameCardView: View {
    let game: Game
    let onJoin: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Host avatar
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
                    Text(game.hostName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)

                    Text(game.gameType == .doubles ? "Doubles" : "Singles")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.stackGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.stackBadgeBg)
                        .cornerRadius(8)
                }

                // Time row
                HStack(spacing: 0) {
                    Text(game.time, style: .time)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                    Text(" \u{2022} ")
                        .font(.system(size: 16))
                        .foregroundColor(.stackSecondaryText)
                    Text(game.time, style: .date)
                        .font(.system(size: 16))
                        .foregroundColor(.stackSecondaryText)
                }

                // Location row
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle")
                        .font(.system(size: 13))
                        .foregroundColor(.stackGreen)
                    Text(game.location)
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                    if let distance = game.distanceFromUser {
                        Text("\u{2022} \(String(format: "%.1f", distance)) mi away")
                            .font(.system(size: 14))
                            .foregroundColor(.stackSecondaryText)
                    }
                }

                // DUPR row
                HStack(spacing: 4) {
                    Image(systemName: "trophy")
                        .font(.system(size: 13))
                        .foregroundColor(.stackGreen)
                    Text("DUPR \(String(format: "%.1f", game.skillLevelMin))-\(String(format: "%.1f", game.skillLevelMax))")
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                }

                // Spots row
                HStack(spacing: 4) {
                    Image(systemName: "person.2")
                        .font(.system(size: 13))
                        .foregroundColor(.stackGreen)
                    Text("\(game.currentPlayerCount)/\(game.maxPlayers) spots")
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                }
            }

            Spacer()

            // Join / Request button
            if game.visibility == .publicGame {
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
                Button(action: onJoin) {
                    Text("Request")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.stackGreen)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.stackGreen, lineWidth: 1.5)
                        )
                }
            }
        }
        .padding(16)
        .background(Color.stackCardWhite)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 3)
    }
}

#Preview {
    VStack(spacing: 12) {
        GameCardView(
            game: {
                var g = Game(
                    hostId: UUID(),
                    hostName: "Jessica Lee",
                    location: "Riverside Park",
                    time: Date().addingTimeInterval(7200),
                    skillLevelMin: 3.5,
                    skillLevelMax: 4.0,
                    maxPlayers: 4,
                    currentPlayerCount: 2,
                    visibility: .publicGame,
                    gameType: .doubles
                )
                g.distanceFromUser = 1.2
                return g
            }(),
            onJoin: {}
        )

        GameCardView(
            game: {
                var g = Game(
                    hostId: UUID(),
                    hostName: "David Kim",
                    location: "Central Sports Complex",
                    time: Date().addingTimeInterval(10800),
                    skillLevelMin: 4.0,
                    skillLevelMax: 4.5,
                    maxPlayers: 4,
                    currentPlayerCount: 3,
                    visibility: .privateGame,
                    gameType: .doubles
                )
                g.distanceFromUser = 2.8
                return g
            }(),
            onJoin: {}
        )
    }
    .padding(16)
    .background(Color.stackBackground)
}
