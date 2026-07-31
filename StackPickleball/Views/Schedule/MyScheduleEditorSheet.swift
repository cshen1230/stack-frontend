import SwiftUI

/// Edit the times you usually play. Same grid as onboarding — this is the one place the
/// answer lives, so it should be asked the same way both times.
struct MyScheduleEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ScheduleViewModel

    @State private var isSaving = false
    @State private var isPainting = false
    /// What was on screen when we opened, so Save can tell you whether it has anything to do.
    @State private var original: [Int: Set<DayPart>]?

    private var hasChanges: Bool {
        guard let original else { return false }
        return normalized(viewModel.dayPartSelection) != normalized(original)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Tap a slot, or drag across several. Tap a day or a time to fill the whole line.")
                        .font(.subheadline)
                        .foregroundColor(.stackSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    DayPartGrid(
                        selection: $viewModel.dayPartSelection,
                        isPainting: $isPainting
                    )

                    summary
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            // A paint stroke and a scroll are the same gesture; the grid wins while painting.
            .scrollDisabled(isPainting)
            .background(Color.stackBackground)
            .navigationTitle("When You Play")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        isSaving = true
                        Task {
                            await viewModel.saveSchedule()
                            isSaving = false
                            dismiss()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save").fontWeight(.semibold)
                        }
                    }
                    .disabled(isSaving || !hasChanges)
                }
            }
            .task {
                if original == nil { original = viewModel.dayPartSelection }
            }
        }
    }

    /// Answers "am I done?" without counting boxes, and says something useful when empty.
    private var summary: some View {
        let days = viewModel.dayPartSelection.selectedDayCount

        return HStack(spacing: 7) {
            Image(systemName: days == 0 ? "calendar.badge.exclamationmark" : "checkmark.circle.fill")
                .font(.footnote)
                .foregroundColor(days == 0 ? .stackSecondaryText : .stackGreen)

            Text(days == 0
                 ? "No times yet — friends won't know when to invite you."
                 : "Free \(days) day\(days == 1 ? "" : "s") a week")
                .font(.subheadline.weight(days == 0 ? .regular : .semibold))
                .foregroundColor(days == 0 ? .stackSecondaryText : .primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .animation(Motion.state, value: days)
    }

    /// Empty sets and absent keys mean the same thing; compare them that way.
    private func normalized(_ selection: [Int: Set<DayPart>]) -> [Int: Set<DayPart>] {
        selection.filter { !$0.value.isEmpty }
    }
}
