import SwiftUI
import Combine

/// Day picker + that day's calendar + the draft sheet. Lives inline on Home, and is wrapped by
/// `DayPlannerView` when it needs to be presented modally.
struct DayPlannerBoard: View {
    /// Friends' usual availability keyed by weekday (1 = Sunday, matching Calendar). The
    /// board resolves the selected day's rows onto real times itself.
    let schedulesByWeekday: [Int: [FriendScheduleRow]]
    /// Sessions you're already committed to, drawn as blocks on the day they fall on.
    var mySessions: [Game] = []
    var onCreated: (CreatedSessionInfo) -> Void
    /// Tapping a booked block opens it. Handed up rather than presented here: the board already
    /// owns two sheets, and stacking a third on one view is unreliable.
    var onSessionTapped: (Game) -> Void = { _ in }

    @EnvironmentObject private var locationManager: LocationManager
    @Environment(AppState.self) private var appState

    /// Owns my own availability so the board can both draw it and edit it in place — you
    /// shouldn't have to leave the calendar to say when you play.
    @State private var scheduleViewModel = ScheduleViewModel()
    @State private var showingAvailabilityEditor = false

    @State private var selectedDay = Date()
    @State private var selection: ClosedRange<Date>?
    @State private var draft: SessionDraftViewModel?
    @State private var confirmedInfo: CreatedSessionInfo?
    @State private var selectedFriend: FriendAvailability?
    @State private var now = Date()
    /// The block you drew is where the draft sheet comes from and goes back to.
    @Namespace private var draftTransition

    private let clock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private let calendar = Calendar.current

    /// Friends' windows for the selected day, pinned to real times on that date.
    private var friendSlots: [FriendAvailability] {
        let weekday = calendar.component(.weekday, from: selectedDay)
        return FriendAvailability.resolve(schedulesByWeekday[weekday] ?? [], on: selectedDay)
    }

    /// Mine plus theirs — the calendar shows where I sit among them.
    private var slotsOnSelectedDay: [FriendAvailability] {
        (FriendAvailability.resolveOwn(scheduleViewModel.mySchedule, on: selectedDay) + friendSlots)
            .sorted { $0.start < $1.start }
    }

    /// Which chips get a dot. Availability recurs weekly, so this stays in weekdays and the
    /// strip matches it against whatever week it happens to be showing.
    private var playedWeekdays: Set<Int> {
        Set(schedulesByWeekday.filter { !$0.value.isEmpty }.keys)
    }

    /// My sessions on the day being looked at.
    private var sessionsOnSelectedDay: [Game] {
        mySessions.filter { calendar.isDate($0.gameDatetime, inSameDayAs: selectedDay) }
    }

    var body: some View {
        // One card holds the week, the hint and the grid. Before, the timeline ran the full
        // width of the screen against the page background, which gave a dense grid of lines no
        // edge to stop at and made it read as the whole screen rather than as one control on it.
        VStack(alignment: .leading, spacing: 12) {
            DayStrip(
                selectedDay: $selectedDay,
                playedWeekdays: playedWeekdays
            )

            HStack(alignment: .firstTextBaseline) {
                Text(hint)
                    .font(.system(size: 12))
                    .foregroundColor(.stackSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Button {
                    showingAvailabilityEditor = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 11, weight: .semibold))
                        Text(myTimesLabel)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.stackGreen)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showingAvailabilityEditor) {
                    MyScheduleEditorSheet(viewModel: scheduleViewModel)
                }
            }

            Divider()
                .overlay(Color.stackBorder)

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
                sessions: sessionsOnSelectedDay,
                confirmedInfo: confirmedInfo,
                onFriendTapped: { slot in
                    // Your own band is a shortcut to changing it, not a profile to read.
                    if slot.isSelf {
                        showingAvailabilityEditor = true
                    } else {
                        selectedFriend = slot
                    }
                },
                onSessionTapped: onSessionTapped
            )
            .growsInto("draft", in: draftTransition)
            // Attached to the timeline rather than the root so it doesn't contend with the
            // draft sheet below — stacking two presentations on one view is unreliable.
            .sheet(item: $selectedFriend) { slot in
                FriendAvailabilitySheet(slot: slot)
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
        .shadow(color: .black.opacity(0.04), radius: 10, y: 3)
        .padding(.horizontal, 16)
        .task(id: appState.currentUser?.id) {
            guard let userId = appState.currentUser?.id else { return }
            await scheduleViewModel.loadMySchedule(userId: userId)
        }
        .onReceive(clock) { now = $0 }
        .onChange(of: selectedDay) { withAnimation(Motion.state) { selection = nil; confirmedInfo = nil } }
        // Driven by isPresented rather than item: the draft is a reference type built at the
        // moment of the drag, and presentation here follows "is there a draft", not identity.
        .sheet(isPresented: isDrafting, onDismiss: {
            if confirmedInfo == nil {
                selection = nil
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(Motion.transition) {
                        selection = nil
                        confirmedInfo = nil
                    }
                }
            }
        }) {
            if let draft {
                SessionDraftSheet(viewModel: draft, slots: friendSlots) { info in
                    confirmedInfo = info
                    onCreated(info)
                }
                .grownFrom("draft", in: draftTransition)
            }
        }
    }

    private var isDrafting: Binding<Bool> {
        Binding(
            get: { draft != nil },
            set: { if !$0 { draft = nil } }
        )
    }

    /// Nudges toward setting times when there are none, since an empty calendar looks broken.
    private var myTimesLabel: String {
        scheduleViewModel.mySchedule.isEmpty ? "Set your times" : "Your times"
    }

    private var hint: String {
        // What you already agreed to outranks who might be free — if the day is booked, that's
        // the thing worth saying first.
        let booked = sessionsOnSelectedDay.count
        if booked > 0 {
            return "\(booked) session\(booked == 1 ? "" : "s") booked · hold and drag to plan another"
        }
        let count = Set(friendSlots.map(\.userId)).count
        let who = count == 0
            ? "No friends free"
            : "\(count) friend\(count == 1 ? "" : "s") free"
        return "\(who) · hold and drag to plan a session"
    }
}
