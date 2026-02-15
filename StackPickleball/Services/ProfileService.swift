import Foundation
import Supabase

enum ProfileService {
    static func getProfile(userId: UUID) async throws -> User? {
        try await supabase
            .from("users")
            .select()
            .eq("id", value: userId)
            .maybeSingle()
            .execute()
            .value
    }

    struct CreateProfileRequest: Encodable {
        let first_name: String
        let last_name: String
        var middle_name: String?
        let username: String
        let dupr_rating: Double
        var latitude: Double?
        var longitude: Double?
    }

    static func createProfile(
        firstName: String,
        lastName: String,
        middleName: String?,
        username: String,
        duprRating: Double,
        latitude: Double?,
        longitude: Double?
    ) async throws {
        let request = CreateProfileRequest(
            first_name: firstName,
            last_name: lastName,
            middle_name: middleName,
            username: username,
            dupr_rating: duprRating,
            latitude: latitude,
            longitude: longitude
        )
        try await supabase.functions.invoke("create-profile", options: .init(body: request))
    }

    struct UpdateProfileRequest: Encodable {
        var first_name: String?
        var last_name: String?
        var middle_name: String?
        var username: String?
        var dupr_rating: Double?
        var avatar_url: String?
        var latitude: Double?
        var longitude: Double?
    }

    static func updateProfile(
        firstName: String? = nil,
        lastName: String? = nil,
        middleName: String? = nil,
        username: String? = nil,
        duprRating: Double? = nil,
        avatarUrl: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) async throws {
        let request = UpdateProfileRequest(
            first_name: firstName,
            last_name: lastName,
            middle_name: middleName,
            username: username,
            dupr_rating: duprRating,
            avatar_url: avatarUrl,
            latitude: latitude,
            longitude: longitude
        )
        try await supabase.functions.invoke("update-profile", options: .init(body: request))
    }

    static func uploadAvatar(userId: UUID, imageData: Data) async throws -> String {
        let path = "\(userId.uuidString)/avatar.jpg"
        try await supabase.storage.from("avatars").upload(
            path,
            data: imageData,
            options: .init(contentType: "image/jpeg", upsert: true)
        )
        let publicURL = try supabase.storage.from("avatars").getPublicURL(path: path)
        return publicURL.absoluteString
    }
}
