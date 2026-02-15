import SwiftUI

struct FeedView: View {
    @State private var viewModel = FeedViewModel()
    @State private var showingCreatePost = false

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading && viewModel.posts.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.posts.isEmpty {
                    EmptyStateView(
                        icon: "camera",
                        title: "No Posts Yet",
                        message: "Be the first to share a session photo!",
                        buttonTitle: "Post Session",
                        buttonAction: { showingCreatePost = true }
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.posts) { post in
                                PostCardView(post: post)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                }
            }
            .background(Color.stackBackground)
            .navigationTitle("Feed")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: { showingCreatePost = true }) {
                        Image(systemName: "camera")
                            .font(.system(size: 20))
                            .foregroundColor(.stackGreen)
                    }
                }
            }
            .refreshable {
                await viewModel.loadFeed()
            }
            .task {
                await viewModel.loadFeed()
            }
            .sheet(isPresented: $showingCreatePost) {
                CreatePostView()
            }
            .errorAlert($viewModel.errorMessage)
        }
    }
}

#Preview {
    FeedView()
        .environment(AppState())
        .environmentObject(LocationManager.shared)
}
