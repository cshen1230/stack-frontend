import SwiftUI

extension Color {
    static let stackGreen = Color(hex: "#34A853")
    static let stackBackground = Color(hex: "#F7F7F5")
    static let stackCardWhite = Color(.systemBackground)
    static let stackSecondaryText = Color(.secondaryLabel)
    static let stackBorder = Color(.separator)
    static let stackWinGreen = Color(hex: "#D1FAE5")
    static let stackWinIcon = Color(hex: "#059669")
    static let stackLossRed = Color(hex: "#FEE2E2")
    static let stackLossIcon = Color(hex: "#DC2626")
    static let stackFilterActive = Color.stackGreen
    static let stackFilterInactive = Color(.tertiarySystemFill)
    static let stackDUPRBadge = Color.stackGreen
    static let stackInputIcon = Color(.secondaryLabel)
    static let stackTimestamp = Color(.secondaryLabel)
    static let stackGameDetailBg = Color(.secondarySystemBackground)
    static let stackCourtPlaceholder = Color(hex: "#C4783A")
    static let stackBadgeBg = Color.stackGreen.opacity(0.1)
    static let stackLoginGradientEnd = Color.stackGreen.opacity(0.06)

    // New tokens
    static let stackAccentLight = Color.stackGreen.opacity(0.08)
    static let stackCardShadow = Color.black.opacity(0.04)

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
