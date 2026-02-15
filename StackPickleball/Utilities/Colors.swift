import SwiftUI

extension Color {
    static let stackGreen = Color(hex: "#2D5016")
    static let stackBackground = Color(hex: "#F2F4F0")
    static let stackCardWhite = Color.white
    static let stackSecondaryText = Color(hex: "#6B7280")
    static let stackBorder = Color(hex: "#E5E7EB")
    static let stackWinGreen = Color(hex: "#D1FAE5")
    static let stackWinIcon = Color(hex: "#059669")
    static let stackLossRed = Color(hex: "#FEE2E2")
    static let stackLossIcon = Color(hex: "#DC2626")
    static let stackFilterActive = Color(hex: "#2D5016")
    static let stackFilterInactive = Color(hex: "#F3F4F6")
    static let stackDUPRBadge = Color(hex: "#2D5016")
    static let stackInputIcon = Color(hex: "#9CA3AF")
    static let stackTimestamp = Color(hex: "#9CA3AF")
    static let stackGameDetailBg = Color(hex: "#F9FAFB")
    static let stackCourtPlaceholder = Color(hex: "#C4783A")
    static let stackBadgeBg = Color(hex: "#E8F5E9")
    static let stackLoginGradientEnd = Color(hex: "#F1F8E9")

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
