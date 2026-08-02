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

    private let hourHeight: CGFloat = 52
    private let gutterWidth: CGFloat = 44

    /// Where the drag started, in minutes from the top. Kept so we can build the range in
    /// either direction — dragging upward is just as valid as downward.
    @State private var anchorMinutes: Double?

    private var totalHeight: CGFloat { CGFloat(DayPlan.hourCount) * hourHeight }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            hourGutter

            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    gridLines
                    pastShading
                    availabilityBands(laneWidth: geo.size.width)
                    // Above availability: a booked hour is not a free one, and the block has to
                    // win that argument visually or the calendar lies about what's open.
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

    /// Always at least one snap step long, however small the drag was.
    private func range(from anchor: Double, to other: Double) -> ClosedRange<Date> {
        let lower = min(anchor, other)
        let upper = max(anchor, other)
        let start = DayPlan.date(atMinutes: lower, on: day)
        var end = DayPlan.date(atMinutes: upper, on: day)
        if end <= start {
            end = start.addingTimeInterval(TimeInterval(DayPlan.snapMinutes * 60))
        }
        return start...end
    }

    // MARK: - Pieces

    private var hourGutter: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(0..<DayPlan.hourCount, id: \.self) { offset in
                Text(DayPlan.hourLabel(DayPlan.firstHour + offset))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.stackSecondaryText)
                    .frame(height: hourHeight, alignment: .top)
                    .offset(y: -5)
                    // Anchors so the planner can open on the current hour.
                    .id(DayPlan.firstHour + offset)
            }
        }
        .frame(width: gutterWidth)
        .padding(.trailing, 6)
    }

    private var gridLines: some View {
        VStack(spacing: 0) {
            ForEach(0..<DayPlan.hourCount, id: \.self) { _ in
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
        let bands = DayPlan.bands(for: slots, on: day)
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
        ForEach(DayPlan.sessionBlocks(for: sessions, on: day)) { block in
            SessionBlockView(block: block, isPast: block.game.gameDatetime < now)
                .frame(
                    width: laneWidth,
                    height: max(CGFloat(block.durationMinutes) / 60 * hourHeight - 3, 26)
                )
                .offset(y: CGFloat(block.startMinutes) / 60 * hourHeight)
                .onTapGesture { onSessionTapped(block.game) }
        }
    }

    /// Hours already gone, greyed so it's obvious there's nothing to plan there.
    @ViewBuilder
    private var pastShading: some View {
        let minutes = DayPlan.minutesFromTop(for: now, on: day)
        if minutes > 0 {
            Rectangle()
                .fill(Color.stackSecondaryText.opacity(0.07))
                .frame(height: min(CGFloat(minutes) / 60 * hourHeight, totalHeight))
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var nowIndicator: some View {
        let minutes = DayPlan.minutesFromTop(for: now, on: day)
        if minutes >= 0, minutes <= Double(DayPlan.hourCount * 60) {
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
            let top = DayPlan.minutesFromTop(for: selection.lowerBound, on: day)
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

    private var isCompact: Bool { block.durationMinutes < 50 }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Image(systemName: "figure.pickleball")
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(block.game.gameDatetime.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10, weight: .semibold))
                    .opacity(0.9)
            }

            if !isCompact {
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .opacity(0.85)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.stackGreen.opacity(isPast ? 0.45 : 0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
        )
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
