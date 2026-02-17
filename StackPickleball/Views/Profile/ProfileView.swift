import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = ProfileViewModel()
    @State private var showingEditProfile = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile card with overlapping avatar
                    ZStack(alignment: .top) {
                        // Card body — pushed down so avatar overlaps top
                        VStack(spacing: 12) {
                            // Display name
                            Text(viewModel.user?.displayName ?? "")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.black)

                            // Username with chevron
                            if let username = viewModel.user?.username {
                                Button(action: { showingEditProfile = true }) {
                                    HStack(spacing: 4) {
                                        Text("@\(username)")
                                            .font(.system(size: 15))
                                            .foregroundColor(.stackSecondaryText)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.stackSecondaryText)
                                    }
                                }
                            }

                            // DUPR badge
                            if let dupr = viewModel.user?.duprRating {
                                HStack(spacing: 6) {
                                    Image(systemName: "trophy.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                    Text("\(String(format: "%.1f", dupr)) DUPR")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.stackDUPRBadge)
                                .cornerRadius(18)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 72)
                        .padding(.bottom, 28)
                        .background(Color.white)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.black, lineWidth: 1)
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.stackGreen)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.black, lineWidth: 1)
                                )
                                .offset(x: 3, y: 4)
                        )
                        .padding(.top, 60)

                        // Avatar — overlapping the card top
                        ZStack {
                            if let avatarUrl = viewModel.user?.avatarUrl, let url = URL(string: avatarUrl) {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    avatarPlaceholder
                                }
                                .frame(width: 110, height: 110)
                                .clipShape(Circle())
                            } else {
                                avatarPlaceholder
                            }
                        }
                        .overlay(
                            Circle()
                                .stroke(Color.stackGreen.opacity(0.4), lineWidth: 4)
                                .frame(width: 120, height: 120)
                        )
                        .zIndex(1)
                    }

                    // Past Sessions
                    if !viewModel.pastGames.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Past Sessions")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.leading, 4)

                            ForEach(viewModel.pastGames) { game in
                                PastSessionCard(
                                    game: game,
                                    isHost: game.creatorId == appState.currentUser?.id
                                )
                            }
                        }
                    }

                    // Sign out
                    Button(action: {
                        Task { await viewModel.signOut() }
                    }) {
                        HStack(spacing: 8) {
                            Text("Sign Out")
                                .font(.system(size: 16, weight: .semibold))
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 15))
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.black, lineWidth: 1)
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.red)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.black, lineWidth: 1)
                                )
                                .offset(x: 3, y: 4)
                        )
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .background(Color.stackBackground)
            .navigationTitle("Profile")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingEditProfile = true }) {
                        Text("Edit")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.stackGreen)
                    }
                }
            }
            .task {
                await viewModel.loadProfile()
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView(viewModel: viewModel)
            }
            .errorAlert($viewModel.errorMessage)
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 110, height: 110)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            )
    }
}

#Preview {
    ProfileView()
        .environment(AppState())
        .environmentObject(LocationManager.shared)
}
