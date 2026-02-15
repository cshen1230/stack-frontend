import SwiftUI
import Combine

class CreateGameViewModel: ObservableObject {
    @Published var location: String = ""
    @Published var selectedDate: Date = Date()
    @Published var skillLevelMin: Double = 3.0
    @Published var skillLevelMax: Double = 4.5
    @Published var gameType: GameType = .doubles
    @Published var visibility: GameVisibility = .publicGame
    @Published var maxPlayers: Int = 4
    @Published var notes: String = ""

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showingSuccess: Bool = false

    // MARK: - Game Creation

    func createGame(hostId: UUID, hostName: String) async {
        isLoading = true
        errorMessage = nil

        // TODO: Create game in Supabase
        let _ = Game(
            hostId: hostId,
            hostName: hostName,
            location: location,
            time: selectedDate,
            skillLevelMin: skillLevelMin,
            skillLevelMax: skillLevelMax,
            maxPlayers: maxPlayers,
            visibility: visibility,
            gameType: gameType,
            notes: notes.isEmpty ? nil : notes
        )

        try? await Task.sleep(nanoseconds: 1_000_000_000) // Simulate network delay

        // Mock success
        showingSuccess = true
        isLoading = false

        // Reset form
        resetForm()
    }

    func resetForm() {
        location = ""
        selectedDate = Date()
        skillLevelMin = 3.0
        skillLevelMax = 4.5
        gameType = .doubles
        visibility = .publicGame
        maxPlayers = 4
        notes = ""
    }
}
