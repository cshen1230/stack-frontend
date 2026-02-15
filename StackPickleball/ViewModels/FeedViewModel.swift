import SwiftUI

@Observable
class FeedViewModel {
    var posts: [Post] = []
    var isLoading = false
    var errorMessage: String?

    func loadFeed() async {
        isLoading = true
        errorMessage = nil
        do {
            posts = try await PostService.fetchFeed()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
