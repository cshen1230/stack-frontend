import SwiftUI

@Observable
class AuthViewModel {
    var email = ""
    var password = ""
    var isLoading = false
    var errorMessage: String?

    func signIn() async {
        isLoading = true
        errorMessage = nil
        do {
            try await AuthService.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    var signUpSucceeded = false

    func signUp() async {
        isLoading = true
        errorMessage = nil
        signUpSucceeded = false
        do {
            try await AuthService.signUp(email: email, password: password)
            // If email confirmation is enabled, the user won't be signed in yet
            signUpSucceeded = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
