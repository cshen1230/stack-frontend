import Foundation
import Supabase

enum AuthService {
    static func signIn(email: String, password: String) async throws {
        try await supabase.auth.signIn(email: email, password: password)
    }

    static func signUp(email: String, password: String) async throws {
        try await supabase.auth.signUp(email: email, password: password)
    }

    static func signOut() async throws {
        try await supabase.auth.signOut()
    }

    static func currentUserId() async -> UUID? {
        try? await supabase.auth.session.user.id
    }
}
