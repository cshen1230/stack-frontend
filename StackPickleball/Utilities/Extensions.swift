import SwiftUI
import Supabase

// MARK: - View Extensions

extension View {
    func cardStyle() -> some View {
        self
            .padding(AppConstants.cardPadding)
            .background(Color.white)
            .cornerRadius(AppConstants.cardCornerRadius)
            .shadow(
                color: .black.opacity(AppConstants.shadowOpacity),
                radius: AppConstants.shadowBlur,
                x: 0,
                y: AppConstants.shadowYOffset
            )
    }

    func errorAlert(_ errorMessage: Binding<String?>) -> some View {
        self.alert(
            "Error",
            isPresented: Binding(
                get: {
                    guard let msg = errorMessage.wrappedValue else { return false }
                    // Suppress CancellationError popups (task cancelled during view transitions)
                    return msg.lowercased() != "cancelled"
                },
                set: { if !$0 { errorMessage.wrappedValue = nil } }
            ),
            actions: { Button("OK") { errorMessage.wrappedValue = nil } },
            message: { Text(errorMessage.wrappedValue ?? "") }
        )
    }
}

// MARK: - Error Helpers

extension Error {
    /// True for Swift CancellationError, URLError.cancelled, and NSURLErrorCancelled.
    var isCancellation: Bool {
        if self is CancellationError { return true }
        if let urlError = self as? URLError, urlError.code == .cancelled { return true }
        return (self as NSError).code == NSURLErrorCancelled
            && (self as NSError).domain == NSURLErrorDomain
    }

    /// Message worth putting in front of a user.
    ///
    /// `FunctionsError.httpError` describes itself as "Edge Function returned a non-2xx
    /// status code: 403" and keeps the response body — which is where our functions put the
    /// actual reason, as `{ "error": "..." }` — in an associated `data` value that nothing
    /// ever reads. Decode it so the user (and we) see why the call failed.
    var userFacingMessage: String {
        guard let functionsError = self as? FunctionsError,
              case let .httpError(code, data) = functionsError else {
            return localizedDescription
        }
        if let text = EdgeFunctionFailure.message(fromBody: data) {
            return text
        }
        return EdgeFunctionFailure.message(forStatus: code)
    }
}

private enum EdgeFunctionFailure {
    /// Our functions return `{ "error": ... }`; Supabase's own gateway uses `message`/`msg`.
    private struct Body: Decodable {
        let error: String?
        let message: String?
        let msg: String?
    }

    static func message(fromBody data: Data) -> String? {
        if let body = try? JSONDecoder().decode(Body.self, from: data),
           let text = [body.error, body.message, body.msg]
               .compactMap({ $0 })
               .first(where: { !$0.isEmpty }) {
            return text
        }
        // Some gateway responses are plain text rather than JSON. HTML is never useful.
        let raw = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (raw.isEmpty || raw.hasPrefix("<")) ? nil : raw
    }

    static func message(forStatus code: Int) -> String {
        switch code {
        case 401, 403:
            return "You're not authorized to do that. Try signing out and back in."
        case 404:
            return "That action isn't available right now. Please try again later."
        case 429:
            return "Too many requests. Wait a moment and try again."
        case 500...599:
            return "The server ran into a problem. Please try again."
        default:
            return "Request failed (status \(code))."
        }
    }
}

// MARK: - Date Extensions

extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
