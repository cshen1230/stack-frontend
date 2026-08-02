import SwiftUI

/// Modal wrapper around `DayPlannerBoard`, for the places that reach session creation from a
/// button rather than having the board on screen already.
struct DayPlannerView: View {
    let schedulesByWeekday: [Int: [FriendScheduleRow]]
    var onCreated: (CreatedSessionInfo) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                // Named rather than trailing: onCreated is no longer the last parameter, so a
                // trailing closure would silently bind to onSessionTapped.
                DayPlannerBoard(
                    schedulesByWeekday: schedulesByWeekday,
                    onCreated: { info in
                        onCreated(info)
                        dismiss()
                    }
                )
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color.stackBackground)
            .navigationTitle("Plan a session")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
