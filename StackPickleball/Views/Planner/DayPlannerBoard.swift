import SwiftUI
import Combine

/// Day picker + that day's calendar + the draft sheet. Lives inline on Home, and is wrapped by
/// `DayPlannerView` when it needs to be presented modally.
struct DayPlannerBoard: View {
    /// Friends' usual availability keyed by weekday (1 = Sunday, matching Calendar). The
    /// board resolves the selected day's rows onto real times itself.
    let schedulesByWeekday: [Int: [FriendScheduleRow]]
    var onCreated: (CreatedSessionInfo) -> Void

    @EnvironmentObject private var locationManager: LocationManager

    @State private var selectedDay = Date()
    @State private var selection: ClosedRange<Date>?
    @State private var draft: SessionDraftViewModel?
    @State private var selectedFriend: FriendAvailability?
    @State private var now = Date()

    private let clock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private let calendar = Calendar.current
    /// How far ahead you can plan; shared by the strip and the availability-dot walk.
    private let dayCount = 14

    /// The selected day's windows, pinned to real times on that date.
    private var slotsOnSelectedDay: [FriendAvailability] {
        let weekday = calendar.component(.weekday, from: selectedDay)
        return FriendAvailability.resolve(schedulesByWeekday[weekday] ?? [], on: selectedDay)
    }

    /// Which chips get a dot — any upcoming date whose weekday somebody plays on.
    private var daysWithAvailability: Set<Date> {
        let today = calendar.startOfDay(for: Date())
        let playedWeekdays = Set(schedulesByWeekday.filter { !$0.value.isEmpty }.keys)
        return Set((0..<dayCount).compactMap { offset -> Date? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  playedWeekdays.contains(calendar.component(.weekday, from: day)) else { return nil }
            return day
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DayStrip(
                selectedDay: $selectedDay,
                dayCount: dayCount,
                daysWithAvailability: daysWithAvailability
            )

            Text(hint)
                .font(.system(size: 13))
                .foregroundColor(.stackSecondaryText)
                .padding(.horizontal, 16)

            DayTimelineView(
                day: selectedDay,
                slots: slotsOnSelectedDay,
                now: now,
                selection: $selection,
                onSelectionCommitted: { range in
                    draft = SessionDraftViewModel(
                        range: range,
                        locationName: "",
                        latitude: locationManager.latitude,
                        longitude: locationManager.longitude
                    )
                },
                onFriendTapped: { selectedFriend = $0 }
            )
            .padding(.horizontal, 16)
            // Attached to the timeline rather than the root so it doesn't contend with the
            // draft sheet below — stacking two presentations on one view is unreliable.
            .sheet(item: $selectedFriend) { slot in
                FriendAvailabilitySheet(slot: slot)
            }
        }
        .onReceive(clock) { now = $0 }
        .onChange(of: selectedDay) { selection = nil }
        // Driven by isPresented rather than item: the draft is a reference type built at the
        // moment of the drag, and presentation here follows "is there a draft", not identity.
        .sheet(isPresented: isDrafting, onDismiss: { selection = nil }) {
            if let draft {
                SessionDraftSheet(viewModel: draft, slots: slotsOnSelectedDay) { info in
                    onCreated(info)
                }
            }
        }
    }

    private var isDrafting: Binding<Bool> {
        Binding(
            get: { draft != nil },
            set: { if !$0 { draft = nil } }
        )
    }

    private var hint: String {
        let count = Set(slotsOnSelectedDay.map(\.userId)).count
        let who = count == 0
            ? "No friends free"
            : "\(count) friend\(count == 1 ? "" : "s") free"
        return "\(who) · hold and drag to plan a session"
    }
}
