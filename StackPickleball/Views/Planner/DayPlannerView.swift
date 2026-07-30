import SwiftUI

/// The whole game-creation flow: see who's free today, drag across the hours you want, confirm.
struct DayPlannerView: View {
    let readyFriends: [ReadyFriend]
    var onCreated: (CreatedSessionInfo) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationManager: LocationManager

    @State private var selection: ClosedRange<Date>?
    @State private var draft: SessionDraftViewModel?
    @State private var now = Date()

    private let clock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private let day = Date()

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header

                        DayTimelineView(
                            day: day,
                            friends: readyFriends,
                            now: now,
                            selection: $selection
                        ) { range in
                            draft = SessionDraftViewModel(
                                range: range,
                                locationName: "",
                                latitude: locationManager.latitude,
                                longitude: locationManager.longitude
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
                .onAppear {
                    // Open on the current hour rather than at 6 AM.
                    let hour = Calendar.current.component(.hour, from: now)
                    let target = min(max(hour - 1, DayPlan.firstHour), DayPlan.lastHour - 1)
                    proxy.scrollTo(target, anchor: .top)
                }
            }
            .background(Color.stackBackground)
            .navigationTitle("Pick a time")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onReceive(clock) { now = $0 }
            .sheet(item: $draft) { model in
                SessionDraftSheet(viewModel: model, readyFriends: readyFriends) { info in
                    draft = nil
                    selection = nil
                    onCreated(info)
                    dismiss()
                }
            }
            .onChange(of: draft == nil) {
                // Sheet dismissed without creating — drop the highlight so the grid is clean.
                if draft == nil { selection = nil }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(headline)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
            Text("Touch and hold the grid, then drag across the hours you want.")
                .font(.system(size: 13))
                .foregroundColor(.stackSecondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    private var headline: String {
        // Count what's actually drawn — callers may hand us windows from other days.
        let free = DayPlan.bands(for: readyFriends, on: day).count
        if free == 0 { return "No friends have posted times today" }
        return "\(free) friend\(free == 1 ? "" : "s") free today"
    }
}

/// `sheet(item:)` needs identity; each draft is a distinct session being planned.
extension SessionDraftViewModel: Identifiable {
    var id: Date { range.lowerBound }
}
