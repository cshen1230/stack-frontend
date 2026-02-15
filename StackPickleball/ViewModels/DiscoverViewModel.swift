import SwiftUI
import Combine

class DiscoverViewModel: ObservableObject {
    @Published var games: [Game] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Filter states
    @Published var selectedDUPRMin: Double = 3.0
    @Published var selectedDUPRMax: Double = 4.5
    @Published var selectedDate: Date = Date()
    @Published var selectedDistance: Double = 5.0 // miles

    init() {
        loadGames()
    }

    // MARK: - Data Loading

    func loadGames() {
        isLoading = true

        // TODO: Fetch games from Supabase with filters

        // Mock data based on Figma designs
        var game1 = Game(
            hostId: UUID(),
            hostName: "Jessica Lee",
            hostImageURL: nil,
            location: "Riverside Park",
            time: Date().addingTimeInterval(7200), // 2 hours from now
            skillLevelMin: 3.5,
            skillLevelMax: 4.0,
            maxPlayers: 4,
            currentPlayerCount: 2,
            visibility: .publicGame,
            gameType: .doubles
        )
        game1.distanceFromUser = 1.2

        var game2 = Game(
            hostId: UUID(),
            hostName: "David Kim",
            hostImageURL: nil,
            location: "Central Sports Complex",
            time: Date().addingTimeInterval(10800), // 3 hours from now
            skillLevelMin: 4.0,
            skillLevelMax: 4.5,
            maxPlayers: 4,
            currentPlayerCount: 3,
            visibility: .publicGame,
            gameType: .doubles
        )
        game2.distanceFromUser = 2.8

        games = [game1, game2]
        isLoading = false
    }

    func applyFilters() {
        loadGames() // Reload with new filter parameters
    }

    func joinGame(_ game: Game) async {
        // TODO: Implement join game logic with Supabase
        if let index = games.firstIndex(where: { $0.id == game.id }) {
            games[index].currentPlayerCount += 1
        }
    }
}
