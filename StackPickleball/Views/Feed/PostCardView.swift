import SwiftUI

struct PostCardView: View {
    let post: Post
    let onLike: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.userName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)

                    Text(post.type == .upcomingGame ? "is hosting a game" : "posted from their match")
                        .font(.system(size: 14))
                        .foregroundColor(.stackSecondaryText)
                }

                Spacer()
            }

            if post.type == .gameHighlight {
                gameHighlightContent
            } else if post.type == .upcomingGame {
                upcomingGameContent
            }
        }
        .padding(16)
        .background(Color.stackCardWhite)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 3)
    }

    // MARK: - Variant A: Game Highlight

    @ViewBuilder
    private var gameHighlightContent: some View {
        // Media placeholder
        if post.mediaURL != nil {
            Rectangle()
                .fill(Color.stackCourtPlaceholder)
                .frame(height: 180)
                .cornerRadius(12)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.6))
                )
                .padding(.top, 12)
        }

        // Engagement row
        HStack(spacing: 24) {
            Button(action: onLike) {
                HStack(spacing: 6) {
                    Image(systemName: "heart")
                    Text("\(post.likes)")
                }
                .foregroundColor(.black)
            }

            HStack(spacing: 6) {
                Image(systemName: "bubble.right")
                Text("\(post.comments)")
            }
            .foregroundColor(.black)
        }
        .font(.system(size: 16))
        .padding(.top, 12)

        // Caption
        if let content = post.content {
            Text(content)
                .font(.system(size: 15))
                .foregroundColor(.black)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
        }

        // Timestamp
        Text(post.timestamp, style: .relative)
            .font(.system(size: 13))
            .foregroundColor(.stackTimestamp)
            .padding(.top, 8)
    }

    // MARK: - Variant B: Upcoming Game

    @ViewBuilder
    private var upcomingGameContent: some View {
        if let details = post.gameDetails {
            // Game details block
            VStack(alignment: .leading, spacing: 12) {
                // Date/time row
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 18))
                        .foregroundColor(.stackGreen)
                    Text(details.time, format: .dateTime.weekday(.wide).month().day().hour().minute())
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                }

                // Location row
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.stackGreen)
                    Text(details.location)
                        .font(.system(size: 15))
                        .foregroundColor(.black)
                }

                // DUPR row
                HStack(spacing: 8) {
                    Image(systemName: "trophy")
                        .font(.system(size: 18))
                        .foregroundColor(.stackGreen)
                    Text(details.skillLevel)
                        .font(.system(size: 15))
                        .foregroundColor(.black)
                }

                // Players row
                HStack(spacing: 8) {
                    Image(systemName: "person.2")
                        .font(.system(size: 18))
                        .foregroundColor(.stackGreen)
                    Text(details.playerCount)
                        .font(.system(size: 15))
                        .foregroundColor(.black)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.stackGameDetailBg)
            .cornerRadius(12)
            .padding(.top, 16)

            // Bottom row: timestamp + join button
            HStack {
                Text(post.timestamp, style: .relative)
                    .font(.system(size: 13))
                    .foregroundColor(.stackTimestamp)

                Spacer()

                Button(action: {
                    // TODO: Join game action
                }) {
                    Text("Join Game")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)
                        .background(Color.stackGreen)
                        .cornerRadius(10)
                }
            }
            .padding(.top, 14)
        }
    }
}

#Preview("Game Highlight") {
    PostCardView(
        post: Post(
            userId: UUID(),
            userName: "Sarah Mitchell",
            type: .gameHighlight,
            content: "Great doubles match this morning! Love this community",
            mediaURL: "placeholder",
            likes: 24,
            comments: 5,
            timestamp: Date().addingTimeInterval(-4 * 3600)
        ),
        onLike: {}
    )
    .padding(16)
    .background(Color.stackBackground)
}

#Preview("Upcoming Game") {
    PostCardView(
        post: Post(
            userId: UUID(),
            userName: "Alex Martinez",
            type: .upcomingGame,
            gameDetails: GameDetails(
                time: Date().addingTimeInterval(86400),
                location: "Community Center Courts",
                skillLevel: "DUPR 4.0-4.5",
                playerCount: "3/4 players"
            ),
            timestamp: Date().addingTimeInterval(-5 * 3600)
        ),
        onLike: {}
    )
    .padding(16)
    .background(Color.stackBackground)
}
