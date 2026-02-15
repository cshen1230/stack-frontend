import Foundation
import CoreLocation

struct Game: Identifiable, Codable, Sendable {
    let id: UUID
    let hostId: UUID
    var hostName: String
    var hostImageURL: String?
    var location: String
    var latitude: Double?
    var longitude: Double?
    var time: Date
    var skillLevelMin: Double // DUPR range min
    var skillLevelMax: Double // DUPR range max
    var players: [UUID]
    var maxPlayers: Int // e.g., 4 for doubles
    var currentPlayerCount: Int
    var visibility: GameVisibility
    var gameType: GameType
    var notes: String?
    var createdAt: Date

    // Computed properties
    var spotsAvailable: Int {
        maxPlayers - currentPlayerCount
    }

    var coordinates: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var distanceFromUser: Double? // In miles, computed at runtime

    private enum CodingKeys: String, CodingKey {
        case id, hostId, hostName, hostImageURL, location
        case latitude, longitude, time
        case skillLevelMin, skillLevelMax
        case players, maxPlayers, currentPlayerCount
        case visibility, gameType, notes, createdAt
    }

    init(
        id: UUID = UUID(),
        hostId: UUID,
        hostName: String,
        hostImageURL: String? = nil,
        location: String,
        coordinates: CLLocationCoordinate2D? = nil,
        time: Date,
        skillLevelMin: Double,
        skillLevelMax: Double,
        players: [UUID] = [],
        maxPlayers: Int = 4,
        currentPlayerCount: Int = 1,
        visibility: GameVisibility = .publicGame,
        gameType: GameType = .doubles,
        notes: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.hostId = hostId
        self.hostName = hostName
        self.hostImageURL = hostImageURL
        self.location = location
        self.latitude = coordinates?.latitude
        self.longitude = coordinates?.longitude
        self.time = time
        self.skillLevelMin = skillLevelMin
        self.skillLevelMax = skillLevelMax
        self.players = players
        self.maxPlayers = maxPlayers
        self.currentPlayerCount = currentPlayerCount
        self.visibility = visibility
        self.gameType = gameType
        self.notes = notes
        self.createdAt = createdAt
        self.distanceFromUser = nil
    }
}
