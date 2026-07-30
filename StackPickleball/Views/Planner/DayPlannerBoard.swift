import SwiftUI
import Combine

/// Day picker + that day's calendar + the draft sheet. Lives inline on Home, and is wrapped by
/// `DayPlannerView` when it needs to be presented modally.
struct DayPlannerBoard: View {
    /// Every unexpired availability window; the board picks out the selected day itself.
    let friends: [ReadyFriend]
    var onCreated: (CreatedSessionInfo) -> Void

    @EnvironmentObject private var locationManager: LocationManager

    @State private var selectedDay = Date()
    @State private var selection: ClosedRange<Date>?
    @State private var draft: SessionDraftViewModel?
    @State private var selectedFriend: ReadyFriend?
    @State private var now = Date()

    private let clock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private let calendar = Calendar.current
    /// How far ahead you can plan; shared by the strip and the availability-dot walk.
    private let dayCount = 14

    /// Only the windows that touch the selected day.
    private var friendsOnSelectedDay: [ReadyFriend] {
        let start = DayPlan.dayStart(of: selectedDay)
        let end = DayPlan.dayEnd(of: selectedDay)
        return friends.filter {
            ($0.availableFrom ?? .distantPast) < end && $0.availableUntil > start
        }
    }

    /// Which chips get a dot.
    private var daysWithAvailability: Set<Date> {
        let today = calendar.startOfDay(for: Date())
        var days: Set<Date> = []
        for friend in friends {
            var cursor = calendar.startOfDay(for: max(friend.availableFrom ?? today, today))
            // Windows are short; walk the days they span rather than every day on the strip.
            // Bounded so a bad row with a runaway end date can't spin here.
            for _ in 0..<dayCount {
                guard cursor < friend.availableUntil else { break }
                days.insert(cursor)
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
        }
        return days
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
                friends: friendsOnSelectedDay,
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
            // Kept on the timeline rather than the root so it doesn't contend with the
            // draft sheet below — two `sheet(item:)` on one view don't coexist reliably.
            .sheet(item: $selectedFriend) { friend in
                ReadyFriendDetailSheet(friend: friend, onCreateGame: {}, onInviteToGame: {})
            }
        }
        .onReceive(clock) { now = $0 }
        .onChange(of: selectedDay) { selection = nil }
        .sheet(item: $draft) { model in
            SessionDraftSheet(viewModel: model, readyFriends: friendsOnSelectedDay) { info in
                draft = nil
                selection = nil
                onCreated(info)
            }
        }
        .onChange(of: draft == nil) {
            // Dismissed without creating — clear the highlight.
            if draft == nil { selection = nil }
        }
    }

    private var hint: String {
        let count = friendsOnSelectedDay.count
        let who = count == 0
            ? "No friends free"
            : "\(count) friend\(count == 1 ? "" : "s") free"
        return "\(who) · hold and drag to plan a session"
    }
}
