import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = ProfileViewModel()
    @State private var showingEditProfile = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Top section — centered profile header
                    VStack(spacing: 12) {
                        // Avatar with colored ring
                        ZStack(alignment: .bottom) {
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

                        // Display name
                        Text(viewModel.user?.displayName ?? "")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.top, 4)

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
                    .padding(.vertical, 24)
                    .background(Color.white)

                    Rectangle()
                        .fill(Color.stackBorder)
                        .frame(height: 1)

                    // Sign out
                    VStack(spacing: 16) {
                        Button(action: {
                            Task { await viewModel.signOut() }
                        }) {
                            Text("Sign Out")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                    }

                    Spacer(minLength: 24)
                }
            }
            .background(Color.stackBackground)
            .navigationTitle("Profile")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {}) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                    }
                }
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
