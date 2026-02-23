import Foundation

struct RoundRobinRound: Identifiable, Codable, Sendable {
    let id: UUID
    let gameId: UUID
    let roundNumber: Int
    let courtNumber: Int
    let team1Player1: UUID
    let team1Player2: UUID?
    let team2Player1: UUID
    let team2Player2: UUID?
    let byePlayers: [UUID]
    var team1Score: Int?
    var team2Score: Int?
    var scoreEnteredBy: UUID?
    let createdAt: Date

    var hasScore: Bool { team1Score != nil && team2Score != nil }

    enum CodingKeys: String, CodingKey {
        case id
        case gameId = "game_id"
        case roundNumber = "round_number"
        case courtNumber = "court_number"
        case team1Player1 = "team1_player1"
        case team1Player2 = "team1_player2"
        case team2Player1 = "team2_player1"
        case team2Player2 = "team2_player2"
        case byePlayers = "bye_players"
        case team1Score = "team1_score"
        case team2Score = "team2_score"
        case scoreEnteredBy = "score_entered_by"
        case createdAt = "created_at"
    }
}
