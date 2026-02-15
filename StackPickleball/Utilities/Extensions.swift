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
}

// MARK: - Date Extensions

extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
