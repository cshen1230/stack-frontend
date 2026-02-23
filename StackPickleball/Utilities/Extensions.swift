import SwiftUI

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
}

// MARK: - Date Extensions

extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
