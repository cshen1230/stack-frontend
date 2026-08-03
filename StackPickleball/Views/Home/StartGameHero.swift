import SwiftUI

/// The top of Home: what this app is for, and the fastest way to do it.
///
/// The screen used to open on a week strip over an hour grid under the heading "Plan a Session",
/// which is a scheduling app. Nothing above the fold said what the thing being scheduled was.
/// This says it in the first line and gives you two ways to act on it before the calendar is
/// even in view — a tap on a slot that already works, or a button that opens the same sheet the
/// drag does.
struct StartGameHero: View {
    let suggestions: [SessionSuggestion]
    /// True once we know whether there are suggestions, so the row doesn't flash empty.
    let isLoaded: Bool
    var onStart: () -> Void
    var onPick: (SessionSuggestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Get a game together")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.stackSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onStart) {
                HStack(spacing: 7) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                    Text("Start a game")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.stackGreen)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            if isLoaded, !suggestions.isEmpty {
                suggestionRow
            }
        }
        .padding(.horizontal, 16)
    }

    /// Says what to do when there's nothing to suggest, and what's on offer when there is.
    private var subtitle: String {
        guard isLoaded else { return "Finding times that work…" }
        if suggestions.isEmpty {
            return "Pick a time below and invite whoever you want to play with."
        }
        return "These times already work for people. Tap one, or pick your own below."
    }

    private var suggestionRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions) { suggestion in
                    Button {
                        onPick(suggestion)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title())
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)

                            HStack(spacing: 4) {
                                if suggestion.friendCount > 0 {
                                    Image(systemName: "person.2.fill")
                                        .font(.system(size: 9, weight: .semibold))
                                }
                                Text(suggestion.subtitle)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(suggestion.friendCount > 0 ? .stackGreen : .stackSecondaryText)
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12).fill(Color.stackCardWhite)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.stackBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            // The row can outrun the screen, unlike the week strip — it's a short list of
            // offers, not a fixed set of columns that has to line up with anything.
            .padding(.horizontal, 1)
        }
        .scrollClipDisabled()
    }
}
