import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = ProfileViewModel()
    @State private var showingEditProfile = false

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading && viewModel.user == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let user = viewModel.user {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Profile card with overlapping avatar
                            profileCard(user: user)

                            // Friends button
                            NavigationLink {
                                FriendsView()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "person.2.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.stackGreen)
                                    Text("Friends")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding(16)
                                .background(Color.stackCardWhite)
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.black, lineWidth: 1)
                                )
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.stackGreen)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(Color.black, lineWidth: 1)
                                        )
                                        .offset(x: 3, y: 4)
                                )
                            }

                            // Calendar section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Past Sessions")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(.leading, 4)

                                SessionCalendarView(
                                    pastGames: viewModel.pastGames,
                                    currentUserId: appState.currentUser?.id
                                )
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
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.25), value: viewModel.user != nil)
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

    // MARK: - Profile Card

    private func profileCard(user: User) -> some View {
        ZStack(alignment: .top) {
            // Card body
            VStack(spacing: 14) {
                // Display name
                Text(user.displayName)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.black)

                // Username
                Button(action: { showingEditProfile = true }) {
                    HStack(spacing: 4) {
                        Text("@\(user.username)")
                            .font(.system(size: 15))
                            .foregroundColor(.stackSecondaryText)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.stackSecondaryText)
                    }
                }

                // DUPR badge
                if let dupr = user.duprRating {
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

                // Stats row
                Divider()
                    .padding(.horizontal, 8)
                    .padding(.top, 4)

                HStack(spacing: 0) {
                    statItem(
                        label: "Total Sessions",
                        value: "\(viewModel.pastGames.count)"
                    )

                    Rectangle()
                        .fill(Color.stackBorder)
                        .frame(width: 1, height: 36)

                    statItem(
                        label: "Friends",
                        value: "\(viewModel.friendCount)"
                    )
                }
                .padding(.bottom, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 72)
            .padding(.bottom, 20)
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
                if let avatarUrl = user.avatarUrl, let url = URL(string: avatarUrl) {
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
    }

    // MARK: - Stat Item

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.stackSecondaryText)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.black)
        }
        .frame(maxWidth: .infinity)
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
