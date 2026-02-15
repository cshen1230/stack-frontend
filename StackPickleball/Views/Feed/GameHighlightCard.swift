import SwiftUI

struct GameHighlightCard: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User header
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.userName)
                        .font(.system(size: 16, weight: .semibold))
                    Text("Game Highlight")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(post.timestamp, style: .relative)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            // Highlight image placeholder
            if post.mediaURL != nil {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#2D5016").opacity(0.3), Color(hex: "#8BC34A").opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 200)
                    .cornerRadius(12)
                    .overlay(
                        VStack {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 36))
                                .foregroundColor(Color(hex: "#2D5016").opacity(0.5))
                            Text("Game Highlight")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "#2D5016").opacity(0.7))
                        }
                    )
            }

            // Caption
            if let content = post.content {
                Text(content)
                    .font(.system(size: 15))
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Engagement
            HStack(spacing: 24) {
                HStack(spacing: 6) {
                    Image(systemName: "heart")
                    Text("\(post.likes)")
                }

                HStack(spacing: 6) {
                    Image(systemName: "bubble.right")
                    Text("\(post.comments)")
                }

                Spacer()

                Image(systemName: "square.and.arrow.up")
            }
            .font(.system(size: 16))
            .foregroundColor(.primary)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}
