import SwiftUI

/// Today on a single vertical timeline: friends' availability as bands, and a drag anywhere
/// on the grid to block out a session.
struct DayTimelineView: View {
    let day: Date
    let slots: [FriendAvailability]
    let now: Date
    /// Live while dragging, so the parent can show the range it's about to create.
    @Binding var selection: ClosedRange<Date>?
    var onSelectionCommitted: (ClosedRange<Date>) -> Void
    /// Sessions already booked on this day, drawn as solid blocks over the free time.
    var sessions: [Game] = []
    /// Post-creation info — when set, the selection overlay morphs into a confirmed indicator.
    var confirmedInfo: CreatedSessionInfo? = nil
    /// Tapping someone's band opens their details. A tap is distinct from the hold-and-drag
    /// that plans a session, so the two gestures don't collide.
    var onFriendTapped: (FriendAvailability) -> Void = { _ in }
    var onSessionTapped: (Game) -> Void = { _ in }
    /// Ties the drawn block to the draft sheet, so the sheet grows out of the slot you chose
    /// rather than sliding up from the bottom of the screen with no stated origin.
    var draftTransition: Namespace.ID?

    private let hourHeight: CGFloat = 50
    private let gutterWidth: CGFloat = 44

    /// Set once the reader asks for the whole day, which turns the trimming off for good.
    @State private var showingAllHours = false

    /// The hours drawn. Trimmed to what's on the day so the grid stays a control on the page
    /// rather than a page of its own — with a way out, because a window that quietly refuses to
    /// let you plan a 7am game would be worse than a tall one.
    private var window: DayPlan.HourWindow {
        guard !showingAllHours else { return .full }
        let content = slots.map { $0.start...$0.end }
            + sessions.map { $0.gameDatetime...$0.gameDatetime.addingTimeInterval(DayPlan.assumedSessionMinutes * 60) }
        return DayPlan.HourWindow.fitting(content, on: day, now: now)
    }

    private var isTrimmed: Bool { window != .full }

    /// Where the drag started, in minutes from the top. Kept so we can build the range in
    /// either direction — dragging upward is just as valid as downward.
    @State private var anchorMinutes: Double?

    private var totalHeight: CGFloat { CGFloat(window.hourCount) * hourHeight }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 0) {
                hourGutter

                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        gridLines
                        pastShading
                        dragAffordance(laneWidth: geo.size.width)
                        availabilityBands(laneWidth: geo.size.width)
                        // Above availability: a booked hour is not a free one, and the block has
                        // to win that argument visually or the calendar lies about what's open.
                        sessionBlocks(laneWidth: geo.size.width)
                        nowIndicator
                        selectionOverlay(laneWidth: geo.size.width)
                    }
                    .frame(width: geo.size.width, height: totalHeight)
                    .contentShape(Rectangle())
                    .gesture(plannerGesture)
                }
                .frame(height: totalHeight)
            }
            .frame(height: totalHeight)

            if isTrimmed {
                Button {
                    withAnimation(Motion.transition) { showingAllHours = true }
                } label: {
                    Text("Show all hours")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.stackSecondaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .animation(Motion.transition, value: window)
    }

    // MARK: - Gesture

    /// Hold, then drag. The hold is what lets this coexist with the surrounding scroll view —
    /// a bare drag would be swallowed by scrolling before it ever reached the grid.
    private var plannerGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.22)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard case .second(true, let drag?) = value else { return }
                let anchor = anchorMinutes ?? minutes(fromY: drag.startLocation.y)
                if anchorMinutes == nil { anchorMinutes = anchor }
                selection = range(from: anchor, to: minutes(fromY: drag.location.y))
            }
            .onEnded { value in
                guard case .second(true, let drag?) = value else {
                    anchorMinutes = nil
                    return
                }
                let anchor = anchorMinutes ?? minutes(fromY: drag.startLocation.y)
                // Holding without moving still means "a session here" — give it an hour.
                let moved = abs(drag.location.y - drag.startLocation.y) > 6
                let result = moved
                    ? range(from: anchor, to: minutes(fromY: drag.location.y))
                    : range(from: anchor, to: anchor + 60)
                anchorMinutes = nil
                selection = result
                onSelectionCommitted(result)
            }
    }

    private func minutes(fromY y: CGFloat) -> Double {
        Double(y / hourHeight) * 60
    }

    /// A dashed ghost where a session would go, shown only when the day is otherwise empty.
    ///
    /// Hold-and-drag has no affordance of its own — an empty grid looks like a picture of a
    /// grid. This is the one place the gesture can be taught at the moment it's needed, and it
    /// disappears the instant there's anything real to look at.
    @ViewBuilder
    private func dragAffordance(laneWidth: CGFloat) -> some View {
        if slots.isEmpty, sessions.isEmpty, selection == nil {
            let top = DayPlan.minutesFromTop(for: ghostStart, on: day, window: window)
            if top >= 0, top < Double(window.hourCount * 60) {
                VStack(spacing: 3) {
                    Image(systemName: "hand.draw")
                        .font(.system(size: 15, weight: .medium))
                    Text("Hold and drag")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.stackGreen.opacity(0.7))
                .frame(width: laneWidth, height: hourHeight * 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.stackGreen.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            Color.stackGreen.opacity(0.45),
                            style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                        )
                )
                .offset(y: CGFloat(top) / 60 * hourHeight)
                .allowsHitTesting(false)
            }
        }
    }

    /// Where the ghost sits: early evening, or the next clear hour if that's already gone.
    private var ghostStart: Date {
        let calendar = Calendar.current
        let evening = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day) ?? day
        guard calendar.isDate(day, inSameDayAs: now), now > evening else { return evening }
        return DayPlan.date(atMinutes: DayPlan.minutesFromTop(for: now, on: day, window: window) + 60,
                            on: day, window: window)
    }

    /// Always at least one snap step long, however small the drag was.
    private func range(from anchor: Double, to other: Double) -> ClosedRange<Date> {
        let lower = min(anchor, other)
        let upper = max(anchor, other)
        let start = DayPlan.date(atMinutes: lower, on: day, window: window)
        var end = DayPlan.date(atMinutes: upper, on: day, window: window)
        if end <= start {
            end = start.addingTimeInterval(TimeInterval(DayPlan.snapMinutes * 60))
        }
        return start...end
    }

    // MARK: - Pieces

    private var hourGutter: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(0..<window.hourCount, id: \.self) { offset in
                Text(DayPlan.hourLabel(window.first + offset))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.stackSecondaryText)
                    .frame(height: hourHeight, alignment: .top)
                    .offset(y: -5)
                    // Anchors so the planner can open on the current hour.
                    .id(window.first + offset)
            }
        }
        .frame(width: gutterWidth)
        .padding(.trailing, 6)
    }

    private var gridLines: some View {
        VStack(spacing: 0) {
            ForEach(0..<window.hourCount, id: \.self) { _ in
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.stackBorder.opacity(0.7))
                        .frame(height: 1)
                    Spacer(minLength: 0)
                }
                .frame(height: hourHeight)
            }
        }
    }

    @ViewBuilder
    private func availabilityBands(laneWidth: CGFloat) -> some View {
        let bands = DayPlan.bands(for: slots, on: day, window: window)
        ForEach(bands) { band in
            let width = laneWidth / CGFloat(band.columnCount)
            AvailabilityBandView(band: band, isLive: band.slot.end > now && band.slot.start <= now)
                .frame(
                    width: max(width - 4, 40),
                    height: max(CGFloat(band.durationMinutes) / 60 * hourHeight - 3, 22)
                )
                .offset(
                    x: width * CGFloat(band.column) + 2,
                    y: CGFloat(band.startMinutes) / 60 * hourHeight
                )
                .onTapGesture { onFriendTapped(band.slot) }
        }
    }

    /// Sessions already on the books for this day.
    @ViewBuilder
    private func sessionBlocks(laneWidth: CGFloat) -> some View {
        ForEach(DayPlan.sessionBlocks(for: sessions, on: day, window: window)) { block in
            let width = laneWidth / CGFloat(block.columnCount)
            SessionBlockView(
                block: block,
                isPast: block.game.gameDatetime < now,
                isNarrow: block.columnCount > 1
            )
            .frame(
                width: max(width - 3, 44),
                height: max(CGFloat(block.durationMinutes) / 60 * hourHeight - 3, 26)
            )
            .offset(
                x: width * CGFloat(block.column) + 1.5,
                y: CGFloat(block.startMinutes) / 60 * hourHeight
            )
            .onTapGesture { onSessionTapped(block.game) }
        }
    }

    /// Hours already gone, greyed so it's obvious there's nothing to plan there.
    @ViewBuilder
    private var pastShading: some View {
        let minutes = DayPlan.minutesFromTop(for: now, on: day, window: window)
        if minutes > 0 {
            Rectangle()
                .fill(Color.stackSecondaryText.opacity(0.07))
                .frame(height: min(CGFloat(minutes) / 60 * hourHeight, totalHeight))
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var nowIndicator: some View {
        let minutes = DayPlan.minutesFromTop(for: now, on: day, window: window)
        if minutes >= 0, minutes <= Double(window.hourCount * 60) {
            HStack(spacing: 0) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 7, height: 7)
                Rectangle()
                    .fill(Color.red)
                    .frame(height: 1.5)
            }
            .offset(y: CGFloat(minutes) / 60 * hourHeight - 3.5)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func selectionOverlay(laneWidth: CGFloat) -> some View {
        if let selection {
            let top = DayPlan.minutesFromTop(for: selection.lowerBound, on: day, window: window)
            let height = selection.upperBound.timeIntervalSince(selection.lowerBound) / 60

            Group {
                if let info = confirmedInfo {
                    // ── Confirmed state ──
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text("Session Created")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Text(rangeLabel(selection))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))

                        HStack(spacing: 6) {
                            Text(info.gameFormat.displayName)
                                .font(.system(size: 11, weight: .semibold))
                            Text("·")
                            Text("\(info.spotsAvailable) spots")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.white.opacity(0.8))

                        Spacer(minLength: 0)
                    }
                    .padding(8)
                    .frame(width: laneWidth,
                           height: max(CGFloat(height) / 60 * hourHeight, 26),
                           alignment: .topLeading)
                    .background(Color.stackGreen)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.white.opacity(0.4), lineWidth: 1.5)
                    )
                    .shadow(color: Color.stackGreen.opacity(0.5), radius: 10, y: 3)
                    .transition(.identity)
                } else {
                    // ── Draft state ──
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rangeLabel(selection))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        Spacer(minLength: 0)
                    }
                    .padding(8)
                    .frame(width: laneWidth,
                           height: max(CGFloat(height) / 60 * hourHeight, 26),
                           alignment: .topLeading)
                    .background(Color.stackGreen.opacity(0.92))
                    .cornerRadius(10)
                    .shadow(color: Color.stackGreen.opacity(0.4), radius: 8, y: 3)
                }
            }
            .offset(y: CGFloat(top) / 60 * hourHeight)
            .allowsHitTesting(false)
            .animation(Motion.transition, value: confirmedInfo != nil)
            // The source is this block, not the timeline around it. Anchored on the whole grid
            // the zoom had nothing to converge on — a source the size of the screen expanding to
            // a sheet the size of the screen is indistinguishable from no transition at all,
            // which is why it read as an ordinary slide up from the bottom.
            .draftSource(draftTransition)
        }
    }

    private func rangeLabel(_ range: ClosedRange<Date>) -> String {
        let start = range.lowerBound.formatted(date: .omitted, time: .shortened)
        let end = range.upperBound.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }
}

/// A booked session drawn on the grid.
///
/// Deliberately the heaviest thing on the timeline — solid fill against the availability bands'
/// washes. Availability is a maybe and a session is a commitment, and the two should not read
/// as the same weight of thing.
private struct SessionBlockView: View {
    let block: DayPlan.SessionBlock
    let isPast: Bool
    /// True when this block is sharing its row with something it overlaps.
    var isNarrow: Bool = false

    /// Too short to fit a second line of text.
    private var isShort: Bool { block.durationMinutes < 50 }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "figure.pickleball")
                    .font(.system(size: isNarrow ? 9 : 11, weight: .bold))

                // The time leads once the block is narrow: at half width the title truncates to
                // a couple of words, and "9:30" tells you which session this is far better than
                // "Albert Wan'…" does when the one beside it says the same.
                if isNarrow {
                    Text(timeLabel)
                        .font(.system(size: 10, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                } else {
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(timeLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .opacity(0.9)
                }
            }

            if !isShort {
                Text(isNarrow ? title : subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .opacity(0.85)
                    .lineLimit(isNarrow ? 2 : 1)
            }

            Spacer(minLength: 0)
        }
        .foregroundColor(.white)
        .padding(.horizontal, isNarrow ? 6 : 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.stackGreen.opacity(isPast ? 0.45 : 0.95))
        )
        // A visible edge on every block, so two side by side read as two rather than as one
        // wide one — they're the same colour and they touch.
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
        )
    }

    private var timeLabel: String {
        block.game.gameDatetime.formatted(date: .omitted, time: .shortened)
    }

    private var title: String {
        block.game.sessionName ?? "\(block.game.creatorDisplayName)'s Session"
    }

    private var subtitle: String {
        var parts = [block.game.gameFormat.displayName]
        if let location = block.game.locationName, !location.isEmpty { parts.append(location) }
        parts.append("\(block.game.spotsFilled)/\(block.game.spotsAvailable)")
        return parts.joined(separator: " · ")
    }
}

/// One friend's window drawn on the grid.
private struct AvailabilityBandView: View {
    let band: DayPlan.Band
    let isLive: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(band.slot.isSelf ? Color.stackGreen : (isLive ? Color.stackGreen : Color.stackSecondaryText))
                .frame(width: 20, height: 20)
                .overlay(
                    Text(initial)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                )

            if band.durationMinutes >= 45 || band.columnCount == 1 {
                Text(band.slot.shortName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.stackGreen.opacity(band.slot.isSelf ? 0.22 : (isLive ? 0.18 : 0.1)))
        )
        // Your own window gets a solid edge; friends' stay light, so the two read apart at a glance.
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    Color.stackGreen.opacity(band.slot.isSelf ? 0.9 : (isLive ? 0.5 : 0.25)),
                    lineWidth: band.slot.isSelf ? 2 : 1
                )
        )
    }

    private var initial: String {
        String(band.slot.shortName.prefix(1)).uppercased()
    }
}


private extension View {
    /// `growsInto` needs a namespace; the timeline is used in places that don't have one.
    @ViewBuilder
    func draftSource(_ namespace: Namespace.ID?) -> some View {
        if let namespace {
            growsInto("draft", in: namespace)
        } else {
            self
        }
    }
}
