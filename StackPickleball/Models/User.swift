import Foundation

struct User: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var email: String
    var duprRating: Double?
    var profileImageURL: String?
    var location: String?
    var preferredSide: PlayingSide?
    var playStyle: String?
    var matchHistory: [UUID]
    var availability: [AvailabilitySlot]
    var favoriteCourts: [String]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        email: String,
        duprRating: Double? = nil,
        profileImageURL: String? = nil,
        location: String? = nil,
        preferredSide: PlayingSide? = nil,
        playStyle: String? = nil,
        matchHistory: [UUID] = [],
        availability: [AvailabilitySlot] = [],
        favoriteCourts: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.duprRating = duprRating
        self.profileImageURL = profileImageURL
        self.location = location
        self.preferredSide = preferredSide
        self.playStyle = playStyle
        self.matchHistory = matchHistory
        self.availability = availability
        self.favoriteCourts = favoriteCourts
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
