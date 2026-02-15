import SwiftUI
import PhotosUI

@Observable
class CreatePostViewModel {
    var caption = ""
    var selectedImageData: Data?
    var isLoading = false
    var errorMessage: String?
    var showingSuccess = false

    func createPost(lat: Double?, lng: Double?) async {
        guard let imageData = selectedImageData else {
            errorMessage = "Please select a photo"
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            guard let userId = await AuthService.currentUserId() else {
                errorMessage = "Not signed in"
                isLoading = false
                return
            }

            let mediaUrl = try await PostService.uploadMedia(
                userId: userId,
                data: imageData,
                isVideo: false
            )

            try await PostService.createPost(
                mediaUrl: mediaUrl,
                postType: .sessionPhoto,
                caption: caption.isEmpty ? nil : caption,
                gameId: nil,
                tournamentId: nil,
                latitude: lat,
                longitude: lng,
                locationName: nil
            )
            showingSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
