import SwiftUI

/// The top of Home: what this app is for, and the fastest way to do it.
///
/// The screen used to open on a week strip over an hour grid under the heading "Plan a Session",
/// which is a scheduling app. Nothing above the fold said what the thing being scheduled was.
/// This says it in the first line and gives you two ways to act on it before the calendar is
/// even in view — a tap on a slot that already works, or a button that opens the same sheet the
/// drag does.
struct StartGameHero: View {
    let greeting: String
    let suggestions: [SessionSuggestion]
    /// True once we know whether there are suggestions, so the row doesn't flash empty.
    let isLoaded: Bool
    var onStart: () -> Void
    var onPick: (SessionSuggestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(greeting)
                .font(AppFonts.pageTitle())
                .foregroundColor(.primary)

            Button(action: onStart) {
                HStack(spacing: 7) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                    Text("Start a game")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.stackGreen)
                .clipShape(RoundedRectangle(cornerRadius: AppConstants.buttonCornerRadius))
            }
            .buttonStyle(.plain)

            if isLoaded, !suggestions.isEmpty {
                suggestionRow
            }
        }
        .padding(.horizontal, AppConstants.screenPadding)
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
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
        .scrollClipDisabled()
    }
}
