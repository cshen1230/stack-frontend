import Foundation
import Supabase

enum PostService {
    static func fetchFeed(limit: Int = 50) async throws -> [Post] {
        try await supabase
            .from("posts")
            .select("*, users!inner(username, first_name, last_name, avatar_url)")
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    struct CreatePostRequest: Encodable {
        let media_url: String
        let post_type: String
        var caption: String?
        var game_id: String?
        var tournament_id: String?
        var latitude: Double?
        var longitude: Double?
        var location_name: String?
    }

    static func createPost(
        mediaUrl: String,
        postType: PostType = .sessionPhoto,
        caption: String?,
        gameId: UUID?,
        tournamentId: UUID?,
        latitude: Double?,
        longitude: Double?,
        locationName: String?
    ) async throws {
        let request = CreatePostRequest(
            media_url: mediaUrl,
            post_type: postType.rawValue,
            caption: caption,
            game_id: gameId?.uuidString,
            tournament_id: tournamentId?.uuidString,
            latitude: latitude,
            longitude: longitude,
            location_name: locationName
        )
        try await supabase.functions.invoke("create-post", options: .init(body: request))
    }

    static func uploadMedia(userId: UUID, data: Data, isVideo: Bool) async throws -> String {
        let ext = isVideo ? "mp4" : "jpg"
        let contentType = isVideo ? "video/mp4" : "image/jpeg"
        let filename = "\(UUID().uuidString).\(ext)"
        let path = "\(userId.uuidString)/\(filename)"

        try await supabase.storage.from("post-media").upload(
            path,
            data: data,
            options: .init(contentType: contentType)
        )
        let publicURL = try supabase.storage.from("post-media").getPublicURL(path: path)
        return publicURL.absoluteString
    }
}
