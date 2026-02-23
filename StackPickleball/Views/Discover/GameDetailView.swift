import SwiftUI

struct GameDetailView: View {
    let game: Game
    let isHost: Bool

    @Environment(AppState.self) private var appState
    @State private var participants: [ParticipantWithProfile] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingInviteFriend = false

    private var isParticipant: Bool {
        guard let userId = appState.currentUser?.id else { return false }
        return isHost || participants.contains { $0.userId == userId }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Game info card
                VStack(alignment: .leading, spacing: 10) {
                    // Format badge
                    Text(game.gameFormat.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.stackGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.stackBadgeBg)
                        .cornerRadius(8)

                    // Date & Time
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 13))
                            .foregroundColor(.stackSecondaryText)
                        (Text(game.gameDatetime, format: .dateTime.weekday(.wide))
                        + Text(", ")
                        + Text(game.gameDatetime, format: .dateTime.month(.abbreviated).day())
                        + Text(" at ")
                        + Text(game.gameDatetime, format: .dateTime.hour().minute()))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                    }

                    // Location
                    if let location = game.locationName {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin")
                                .font(.system(size: 13))
                                .foregroundColor(.stackSecondaryText)
                            Text(location)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                    }

                    // DUPR Range
                    if let min = game.skillLevelMin, let max = game.skillLevelMax {
                        HStack(spacing: 6) {
                            Image(systemName: "trophy")
                                .font(.system(size: 13))
                                .foregroundColor(.stackSecondaryText)
                            Text("DUPR \(String(format: "%.1f", min)) – \(String(format: "%.1f", max))")
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                    }

                    // Spots
                    HStack(spacing: 6) {
                        Image(systemName: "person.2")
                            .font(.system(size: 13))
                            .foregroundColor(.stackSecondaryText)
                        Text("\(game.spotsFilled)/\(game.spotsAvailable) spots filled")
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                    }

                    // Description
                    if let desc = game.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.stackCardWhite)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.black, lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Players header
                HStack {
                    Text("Players (\(participants.count))")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 8)

                // Player list
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.top, 20)
                } else if participants.isEmpty {
                    Text("No players yet")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(participants) { participant in
                            PlayerRow(participant: participant, isHost: participant.userId == game.creatorId)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Invite friends button — only for participants when spots remain
                if isParticipant && game.spotsRemaining > 0 {
                    Button {
                        showingInviteFriend = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 16))
                                .foregroundColor(.stackGreen)
                            Text("Invite Friends")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .background(Color.stackCardWhite)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.stackGreen.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }

                // Chat button — only for participants
                if isParticipant {
                    NavigationLink {
                        GameChatView(
                            game: game,
                            currentUserId: appState.currentUser?.id ?? UUID()
                        )
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.stackGreen)
                            Text("Session Chat")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .background(Color.stackCardWhite)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.stackGreen.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.top, 12)
                        .padding(.horizontal, 16)
                }

                Spacer(minLength: 24)
            }
        }
        .background(Color.stackBackground)
        .navigationTitle(game.sessionName ?? game.creatorDisplayName + "'s Game")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await loadParticipants()
        }
        .sheet(isPresented: $showingInviteFriend) {
            InviteFriendSheet(game: game)
        }
    }

    private func loadParticipants() async {
        isLoading = true
        do {
            participants = try await GameService.gameParticipants(gameId: game.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Player Row

private struct PlayerRow: View {
    let participant: ParticipantWithProfile
    let isHost: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Profile picture
            if let avatarUrl = participant.users.avatarUrl, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        avatarPlaceholder
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            } else {
                avatarPlaceholder
                    .frame(width: 48, height: 48)
            }

            // Name + DUPR
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(participant.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)

                    if isHost {
                        HStack(spacing: 2) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 10))
                            Text("Host")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.orange)
                    }
                }

                if let rating = participant.users.duprRating {
                    Text("DUPR \(String(format: "%.1f", rating))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.stackGreen)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(Color.stackCardWhite)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            )
    }
}
