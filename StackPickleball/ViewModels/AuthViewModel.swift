import SwiftUI

@Observable
class AuthViewModel {
    var email = ""
    var password = ""
    var isLoading = false
    var errorMessage: String?

    /// Basic email format check — catches typos before they hit the server.
    private static let emailRegex = /^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$/

    private var isValidEmail: Bool {
        email.trimmingCharacters(in: .whitespaces)
            .wholeMatch(of: Self.emailRegex) != nil
    }

    func signIn() async {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty,
              !password.isEmpty else {
            errorMessage = "Please enter your email and password."
            return
        }
        guard isValidEmail else {
            errorMessage = "Please enter a valid email address."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            try await AuthService.signIn(email: email, password: password)
        } catch {
            errorMessage = error.userFacingMessage
        }
        isLoading = false
    }

    var signUpSucceeded = false

    func signUp() async {
        guard isValidEmail else {
            errorMessage = "Please enter a valid email address."
            return
        }
        isLoading = true
        errorMessage = nil
        signUpSucceeded = false
        do {
            try await AuthService.signUp(email: email, password: password)
            // If email confirmation is enabled, the user won't be signed in yet
            signUpSucceeded = true
        } catch {
            errorMessage = error.userFacingMessage
        }
        isLoading = false
    }
}
