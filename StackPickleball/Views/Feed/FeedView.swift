import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.posts) { post in
                        PostCardView(post: post) {
                            viewModel.likePost(post)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .background(Color.stackBackground)
            .navigationTitle("Feed")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        // TODO: Navigate to notifications
                    }) {
                        Image(systemName: "bell")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                    }
                }
            }
            .refreshable {
                await viewModel.refreshFeed()
            }
        }
    }
}

#Preview {
    FeedView()
}
