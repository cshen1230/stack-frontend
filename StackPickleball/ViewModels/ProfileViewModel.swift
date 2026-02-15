import SwiftUI
import Combine

// Supporting model for match history display
struct MatchHistoryItem: Identifiable, Sendable {
    let id: UUID
    let opponents: String
    let score: String
    let result: MatchResult
    let date: Date
    let location: String
}

class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var matchHistory: [MatchHistoryItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    init() {
        loadProfile()
    }

    // MARK: - Data Loading

    func loadProfile() {
        isLoading = true

        // TODO: Fetch user profile from Supabase

        // Mock data based on Figma designs
        user = User(
            name: "Mike Chen",
            email: "mike@example.com",
            duprRating: 4.2,
            profileImageURL: nil,
            location: "San Francisco, CA",
            favoriteCourts: ["Sunset Park", "Central Courts"]
        )

        // Mock match history
        matchHistory = [
            MatchHistoryItem(
                id: UUID(),
                opponents: "Sarah J. & Mike C.",
                score: "11-9, 11-7",
                result: .win,
                date: Date().addingTimeInterval(-86400), // Yesterday
                location: "Sunset Park"
            ),
            MatchHistoryItem(
                id: UUID(),
                opponents: "Alex M. & Emma D.",
                score: "11-8, 9-11, 11-6",
                result: .win,
                date: Date().addingTimeInterval(-3 * 86400), // 3 days ago
                location: "Central Courts"
            ),
            MatchHistoryItem(
                id: UUID(),
                opponents: "Tom A. & Lisa K.",
                score: "8-11, 11-9, 9-11",
                result: .loss,
                date: Date().addingTimeInterval(-7 * 86400), // 7 days ago
                location: "Riverside Park"
            ),
        ]

        isLoading = false
    }

    func updateProfile(_ updatedUser: User) async {
        // TODO: Update user profile in Supabase
        self.user = updatedUser
    }
}
