import Foundation

enum PostType: String, Codable, Sendable {
    case upcomingGame = "upcoming_game"
    case gameHighlight = "game_highlight"
}

enum GameVisibility: String, Codable, Sendable {
    case publicGame = "public"
    case privateGame = "private"
}

enum GameType: String, Codable, Sendable {
    case singles = "singles"
    case doubles = "doubles"
}

enum PlayingSide: String, Codable, Sendable {
    case forehand = "forehand"
    case backhand = "backhand"
}

enum MatchResult: String, Codable, Sendable {
    case win = "win"
    case loss = "loss"
}
