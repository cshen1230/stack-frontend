import SwiftUI

/// Edit the times you usually play. Same grid as onboarding — this is the one place the
/// answer lives, so it should be asked the same way both times.
struct MyScheduleEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ScheduleViewModel

    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tap the times you usually play. Friends see these on the calendar, so they know when to invite you.")
                        .font(.system(size: 14))
                        .foregroundColor(.stackSecondaryText)

                    DayPartGrid(selection: $viewModel.dayPartSelection)
                }
                .padding(16)
            }
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
                    .disabled(isSaving)
                }
            }
        }
    }
}
