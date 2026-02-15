import SwiftUI
import Combine

class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    init() {
        loadFeed()
    }

    // MARK: - Data Loading

    func loadFeed() {
        isLoading = true

        // TODO: Fetch posts from Supabase
        // Example: posts = await supabase.from('posts').select().order('timestamp', descending: true)

        // Mock data based on Figma designs
        posts = [
            Post(
                userId: UUID(),
                userName: "Sarah Mitchell",
                userImageURL: nil,
                type: .gameHighlight,
                content: "Great doubles match this morning! Love this community",
                mediaURL: "pickleball_court_image",
                likes: 24,
                comments: 5,
                timestamp: Date().addingTimeInterval(-4 * 3600) // 4 hours ago
            ),
            Post(
                userId: UUID(),
                userName: "Alex Martinez",
                userImageURL: nil,
                type: .upcomingGame,
                gameId: UUID(),
                gameDetails: GameDetails(
                    time: Date().addingTimeInterval(86400), // Tomorrow
                    location: "Community Center Courts",
                    skillLevel: "DUPR 4.0-4.5",
                    playerCount: "3/4 players"
                ),
                timestamp: Date().addingTimeInterval(-5 * 3600) // 5 hours ago
            )
        ]

        isLoading = false
    }

    func refreshFeed() async {
        loadFeed()
    }

    func likePost(_ post: Post) {
        // TODO: Implement like functionality with Supabase
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index].likes += 1
        }
    }
}
