import SwiftUI

struct PostCardView: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 10) {
                if let avatarUrl = post.posterAvatarUrl, let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        avatarPlaceholder
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                } else {
                    avatarPlaceholder
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.posterDisplayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)

                    Text(post.postType == .sessionClip ? "shared a clip" : "posted a session photo")
                        .font(.system(size: 14))
                        .foregroundColor(.stackSecondaryText)
                }

                Spacer()

                Text(post.createdAt, style: .relative)
                    .font(.system(size: 13))
                    .foregroundColor(.stackTimestamp)
            }

            // Media
            AsyncImage(url: URL(string: post.mediaUrl)) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(12)
            } placeholder: {
                Rectangle()
                    .fill(Color.stackCourtPlaceholder)
                    .frame(height: 200)
                    .cornerRadius(12)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.6))
                    )
            }
            .padding(.top, 12)

            // Caption
            if let caption = post.caption {
                Text(caption)
                    .font(.system(size: 15))
                    .foregroundColor(.black)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }

            // Location
            if let location = post.locationName {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle")
                        .font(.system(size: 13))
                        .foregroundColor(.stackGreen)
                    Text(location)
                        .font(.system(size: 13))
                        .foregroundColor(.stackSecondaryText)
                }
                .padding(.top, 6)
            }
        }
        .padding(16)
        .background(Color.stackCardWhite)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 3)
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 40, height: 40)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            )
    }
}
