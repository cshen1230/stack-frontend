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
                    Text(post.posterDisplayName)
                        .font(.system(size: 16, weight: .semibold))
                    Text("Session Highlight")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(post.createdAt, style: .relative)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            // Media
            AsyncImage(url: URL(string: post.mediaUrl)) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(12)
            } placeholder: {
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
                        Image(systemName: "photo")
                            .font(.system(size: 36))
                            .foregroundColor(Color(hex: "#2D5016").opacity(0.5))
                    )
            }

            // Caption
            if let caption = post.caption {
                Text(caption)
                    .font(.system(size: 15))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}
