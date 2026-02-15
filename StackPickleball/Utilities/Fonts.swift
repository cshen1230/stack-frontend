import SwiftUI

struct AppFonts {
    // Headers
    static func title() -> Font {
        .system(size: 28, weight: .bold, design: .default)
    }

    static func sectionHeader() -> Font {
        .system(size: 20, weight: .bold, design: .default)
    }

    // Body
    static func body() -> Font {
        .system(size: 16, weight: .regular, design: .default)
    }

    // Captions
    static func caption() -> Font {
        .system(size: 14, weight: .regular, design: .default)
    }

    // Buttons
    static func button() -> Font {
        .system(size: 16, weight: .semibold, design: .default)
    }
}
