import SwiftUI
import Supabase

// MARK: - View Extensions

extension View {
    func cardStyle() -> some View {
        self
            .padding(AppConstants.cardPadding)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardCornerRadius))
            .shadow(
                color: .black.opacity(AppConstants.shadowOpacity),
                radius: AppConstants.shadowBlur,
                x: 0,
                y: AppConstants.shadowYOffset
            )
    }

    /// Card with no shadow, just a thin separator border — for inline sections.
    func sectionCard() -> some View {
        self
            .padding(AppConstants.cardPadding)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.cardCornerRadius)
                    .strokeBorder(Color(.separator), lineWidth: 0.5)
            )
    }

    /// Full-width green CTA with large padding and rounded corners.
    func primaryButton() -> some View {
        self
            .font(.system(size: 17, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.stackGreen)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.buttonCornerRadius))
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
            return EdgeFunctionFailure.humanized(localizedDescription)
        }
        // A 404's body describes our plumbing ("Requested function was not found") and never
        // anything the reader did or can fix, so it never reaches them.
        guard code != 404 else { return EdgeFunctionFailure.message(forStatus: 404) }

        if let text = EdgeFunctionFailure.message(fromBody: data),
           !EdgeFunctionFailure.isPlumbing(text) {
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
            return "That's not available right now. Please try again in a moment."
        case 429:
            return "Too many requests. Wait a moment and try again."
        case 500...599:
            return "Something went wrong on our end. Please try again."
        default:
            return "Something went wrong. Please try again."
        }
    }

    /// Server text that describes infrastructure rather than anything the reader did. Showing
    /// it is worse than saying nothing useful — it reads as a bug report aimed at the user.
    private static let plumbingMarkers = [
        "404", "not found", "requested function", "status code",
        "pgrst", "jwt", "econnrefused", "gateway", "upstream",
    ]

    static func isPlumbing(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return plumbingMarkers.contains { lowered.contains($0) }
    }

    /// Last line of defence for errors that never went through an edge function — URLSession,
    /// PostgREST and friends all have their own ways of leaking status codes into `description`.
    static func humanized(_ description: String) -> String {
        guard !isPlumbing(description) else {
            return "Something went wrong. Please try again."
        }
        return description
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
