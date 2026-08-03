import SwiftUI

/// Placeholder blocks shaped like the content that's coming, instead of a spinner that tells
/// you nothing about what you're waiting for.
struct SkeletonBlock: View {
    var width: CGFloat?
    var height: CGFloat = 12
    var cornerRadius: CGFloat = 6

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.stackSecondaryText.opacity(0.13))
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}

struct SkeletonCircle: View {
    var size: CGFloat = 40

    var body: some View {
        Circle()
            .fill(Color.stackSecondaryText.opacity(0.13))
            .frame(width: size, height: size)
    }
}

/// A light sweep across the placeholders so they read as "loading" rather than "broken".
struct Shimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = -1

    func body(content: Content) -> some View {
        if reduceMotion {
            // A moving highlight is exactly what reduce-motion is asking us not to do.
            content
        } else {
            content
                .overlay(
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.7), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 0.5)
                        .offset(x: offset * geo.size.width * 1.5)
                    }
                    .allowsHitTesting(false)
                )
                .clipped()
                .onAppear {
                    withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                        offset = 1
                    }
                }
        }
    }
}

extension View {
    /// Marks a subtree as a loading placeholder: shimmering, and invisible to VoiceOver, which
    /// should hear "Loading" once rather than a dozen meaningless blocks.
    func skeleton() -> some View {
        self
            .modifier(Shimmer())
            .accessibilityElement()
            .accessibilityLabel("Loading")
    }
}

// MARK: - Composed shapes

/// Avatar plus two lines — people, chats, anything list-shaped.
struct SkeletonRow: View {
    var avatarSize: CGFloat = 40
    var showsTrailing = false

    var body: some View {
        HStack(spacing: 12) {
            SkeletonCircle(size: avatarSize)

            VStack(alignment: .leading, spacing: 6) {
                SkeletonBlock(width: 140, height: 13)
                SkeletonBlock(width: 90, height: 11)
            }

            Spacer(minLength: 0)

            if showsTrailing {
                SkeletonBlock(width: 54, height: 26, cornerRadius: 8)
            }
        }
        .padding(.vertical, 8)
    }
}

/// A game or session card.
struct SkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SkeletonBlock(width: 150, height: 15)
                Spacer(minLength: 0)
                SkeletonBlock(width: 58, height: 22, cornerRadius: 8)
            }
            SkeletonBlock(width: 200, height: 12)
            HStack(spacing: -8) {
                ForEach(0..<3, id: \.self) { _ in SkeletonCircle(size: 26) }
                Spacer(minLength: 0)
                SkeletonBlock(width: 76, height: 28, cornerRadius: 9)
            }
        }
        .padding(14)
        .background(Color.stackCardWhite)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.stackBorder, lineWidth: 1)
        )
    }
}

/// Repeats a shape so a loading list has the weight of a real one.
struct SkeletonList<Content: View>: View {
    var count = 4
    var spacing: CGFloat = 12
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(0..<count, id: \.self) { _ in content() }
        }
        .skeleton()
    }
}

/// Chat bubbles, alternating sides.
struct SkeletonMessages: View {
    var count = 6

    var body: some View {
        VStack(spacing: 14) {
            ForEach(0..<count, id: \.self) { index in
                HStack {
                    if index.isMultiple(of: 2) {
                        SkeletonBlock(width: CGFloat(140 + (index % 3) * 40), height: 34, cornerRadius: 16)
                        Spacer(minLength: 40)
                    } else {
                        Spacer(minLength: 40)
                        SkeletonBlock(width: CGFloat(120 + (index % 3) * 40), height: 34, cornerRadius: 16)
                    }
                }
            }
        }
        .skeleton()
    }
}

/// The Home hero: headline, primary button, and a couple of suggestion chips.
struct SkeletonHero: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                SkeletonBlock(width: 240, height: 24, cornerRadius: 7)
                SkeletonBlock(width: 280, height: 13)
            }

            SkeletonBlock(height: 48, cornerRadius: 14)

            HStack(spacing: 8) {
                SkeletonBlock(width: 140, height: 52, cornerRadius: 12)
                SkeletonBlock(width: 140, height: 52, cornerRadius: 12)
            }
        }
        .padding(.horizontal, 16)
        .skeleton()
    }
}

/// The planner: day chips over an hour grid with a couple of bands.
struct SkeletonPlanner: View {
    private let hourHeight: CGFloat = 52
    private let visibleHours = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Week header: arrows either side of the range label.
            HStack {
                SkeletonCircle(size: 32)
                Spacer()
                SkeletonBlock(width: 96, height: 13)
                Spacer()
                SkeletonCircle(size: 32)
            }

            // Seven chips sharing the width, as the real strip does — a different count here
            // would make the row jump the moment it loads.
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { _ in
                    SkeletonBlock(height: 58, cornerRadius: 12)
                }
            }

            SkeletonBlock(width: 200, height: 11)

            HStack(alignment: .top, spacing: 6) {
                VStack(spacing: 0) {
                    ForEach(0..<visibleHours, id: \.self) { _ in
                        SkeletonBlock(width: 30, height: 10)
                            .frame(height: hourHeight, alignment: .top)
                    }
                }
                .frame(width: 44)

                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        ForEach(0..<visibleHours, id: \.self) { _ in
                            VStack(spacing: 0) {
                                Rectangle()
                                    .fill(Color.stackBorder.opacity(0.7))
                                    .frame(height: 1)
                                Spacer(minLength: 0)
                            }
                            .frame(height: hourHeight)
                        }
                    }

                    SkeletonBlock(height: hourHeight * 1.5 - 4, cornerRadius: 9)
                        .padding(.trailing, 80)
                        .offset(y: hourHeight * 0.5)

                    SkeletonBlock(height: hourHeight - 4, cornerRadius: 9)
                        .padding(.leading, 90)
                        .offset(y: hourHeight * 2.5)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.stackCardWhite)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.stackBorder, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .skeleton()
    }
}
