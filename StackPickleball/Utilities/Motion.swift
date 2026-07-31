import SwiftUI

/// The app's motion language. Four curves, each with one job.
///
/// Before this there were eight ad-hoc springs and easings — `.spring(0.35, 0.8)`,
/// `.spring(0.4, 0.5)`, `.easeOut(0.25)`, `.easeInOut(0.2)` — chosen per call site. Motion
/// only reads as intentional when the same kind of change always moves the same way, so the
/// rule is: pick the curve that matches *what is happening*, never a new number.
enum Motion {
    /// Something is arriving or leaving — a sheet, a toast, a card becoming a screen.
    /// Slightly slower than a state flip because the eye has further to travel.
    static let transition = Animation.spring(duration: 0.38, bounce: 0.14)

    /// A control changed state: a toggle, a selection, a segment. Fast enough to feel like
    /// the tap caused it rather than triggered it.
    static let state = Animation.snappy(duration: 0.2, extraBounce: 0.06)

    /// Following a finger. Interactive springs track input without lag or overshoot.
    static let tracking = Animation.interactiveSpring(duration: 0.28, extraBounce: 0.02)

    /// Content that swaps in place with nowhere to come from — a list reloading behind a
    /// skeleton. No spring: there's no physical motion to imply.
    static let content = Animation.easeOut(duration: 0.22)

    /// How far a control gives under a finger. Small enough to feel like resistance, not a
    /// squash — the haptic carries most of the confirmation.
    static let pressScale: CGFloat = 0.972

    /// Honours Reduce Motion, which asks for cross-fades rather than movement.
    @MainActor
    static func respecting(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? .easeOut(duration: 0.15) : animation
    }
}

// MARK: - Press feedback

/// Tap feedback for every button: a small give, a spring back, one light tick.
///
/// Deliberately not opacity — dimming reads as "disabled", not "pressed" — and deliberately
/// not a bounce. The scale is barely perceptible on its own; the haptic is what the finger
/// actually registers, which is why the two ship together.
struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    var scale: CGFloat = Motion.pressScale

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion || !isEnabled ? 1 : (configuration.isPressed ? scale : 1))
            .animation(Motion.tracking, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.tap() }
            }
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    /// The app default — set once at the root so every button inherits it.
    static var pressable: PressableButtonStyle { PressableButtonStyle() }

    /// For large surfaces (cards, rows) where the standard give reads as too much travel.
    static var pressableSubtle: PressableButtonStyle { PressableButtonStyle(scale: 0.99) }
}

// MARK: - Haptics

/// Selection and confirmation are physical acts; each gets a matching tick. Kept next to the
/// press style because the two always ship together — a scale this small is felt, not seen.
enum Haptics {
    static func tap() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    static func bump() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
}

// MARK: - Contextual presentation

extension View {
    /// Marks this view as where a screen or sheet grows from, so the destination expands out
    /// of it and collapses back into it. Pair with `.grownFrom(_:in:)` on the destination.
    ///
    /// Zoom transitions landed in iOS 18, and this target also builds for macOS and visionOS,
    /// which set no deployment floor of their own. Gating here rather than at each call site
    /// keeps the availability dance in one place; older systems get the standard push, which
    /// is the correct fallback rather than a degraded one.
    @ViewBuilder
    func growsInto(_ id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// The destination half of `growsInto`.
    @ViewBuilder
    func grownFrom(_ id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}
