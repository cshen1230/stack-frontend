import SwiftUI

struct AppFonts {
    /// 34pt bold — iOS large title size. Screen headings and hero greetings.
    static func pageTitle() -> Font {
        .system(size: 34, weight: .bold, design: .default)
    }

    /// 22pt bold — section headings within a screen.
    static func sectionTitle() -> Font {
        .system(size: 22, weight: .bold, design: .default)
    }

    /// 17pt semibold — card titles, row labels, anything that needs emphasis without
    /// being a section heading.
    static func headline() -> Font {
        .system(size: 17, weight: .semibold, design: .default)
    }

    /// 15pt regular — the default reading size.
    static func body() -> Font {
        .system(size: 15, weight: .regular, design: .default)
    }

    /// 14pt regular — secondary body text, supporting info.
    static func callout() -> Font {
        .system(size: 14, weight: .regular, design: .default)
    }

    /// 13pt regular — tertiary labels, timestamps.
    static func subheadline() -> Font {
        .system(size: 13, weight: .regular, design: .default)
    }

    /// 12pt regular — small metadata, hints.
    static func caption() -> Font {
        .system(size: 12, weight: .regular, design: .default)
    }

    /// 11pt regular — the smallest text used anywhere.
    static func caption2() -> Font {
        .system(size: 11, weight: .regular, design: .default)
    }

    // Legacy aliases — keep existing call sites working.

    /// Alias for `sectionTitle()`.
    static func title() -> Font { sectionTitle() }

    /// Alias for `sectionTitle()`.
    static func sectionHeader() -> Font { sectionTitle() }

    /// Alias for `headline()` — button labels.
    static func button() -> Font { headline() }
}
