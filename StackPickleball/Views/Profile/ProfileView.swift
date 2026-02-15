import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = ProfileViewModel()
    @State private var showingEditProfile = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Top section
                    VStack(spacing: 0) {
                        HStack(alignment: .top, spacing: 14) {
                            // Avatar
                            if let avatarUrl = viewModel.user?.avatarUrl, let url = URL(string: avatarUrl) {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    avatarPlaceholder
                                }
                                .frame(width: 90, height: 90)
                                .clipShape(Circle())
                            } else {
                                avatarPlaceholder
                            }

                            // Name + DUPR badge
                            VStack(alignment: .leading, spacing: 8) {
                                Text(viewModel.user?.displayName ?? "")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(.black)

                                if let username = viewModel.user?.username {
                                    Text("@\(username)")
                                        .font(.system(size: 15))
                                        .foregroundColor(.stackSecondaryText)
                                }

                                if let dupr = viewModel.user?.duprRating {
                                    HStack(spacing: 6) {
                                        Image(systemName: "trophy.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                        Text("\(String(format: "%.1f", dupr)) DUPR")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.stackDUPRBadge)
                                    .cornerRadius(16)
                                }
                            }

                            Spacer()

                            // Edit button
                            Button(action: { showingEditProfile = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 14))
                                    Text("Edit")
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .foregroundColor(.stackGreen)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.stackGreen, lineWidth: 1.5)
                                )
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 4)
                    }
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
            .frame(width: 90, height: 90)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.white)
            )
    }
}

#Preview {
    ProfileView()
        .environment(AppState())
        .environmentObject(LocationManager.shared)
}
