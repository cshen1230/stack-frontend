import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Top section (white background)
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 14) {
                        // Avatar
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 90, height: 90)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.white)
                            )

                        // Name + DUPR badge
                        VStack(alignment: .leading, spacing: 8) {
                            Text(viewModel.user?.name ?? "")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.black)

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
                        Button(action: {
                            // TODO: Navigate to edit profile
                        }) {
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

                // Divider
                Rectangle()
                    .fill(Color.stackBorder)
                    .frame(height: 1)

                // Match History section
                VStack(alignment: .leading, spacing: 0) {
                    Text("Match History")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.leading, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 10)

                    // White card container
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.matchHistory.enumerated()), id: \.element.id) { index, match in
                            MatchHistoryRow(match: match)

                            if index < viewModel.matchHistory.count - 1 {
                                Divider()
                                    .padding(.leading, 72)
                            }
                        }
                    }
                    .background(Color.stackCardWhite)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 3)
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 24)
            }
        }
        .background(Color.stackBackground)
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
    }
}

#Preview {
    ProfileView()
}
