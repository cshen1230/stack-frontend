import SwiftUI

/// The whole availability editor: tap the parts of each day you usually play. One grid, used
/// both at onboarding and later from Profile, so there's a single way to express this.
///
/// Contiguous selections in a column draw as one block rather than separate cells, because
/// that's what actually gets saved — `DayPart.mergedWindows` collapses morning plus early
/// afternoon into a single 6am–3pm window, and the grid should say the same thing.
struct DayPartGrid: View {
    /// Weekday (1 = Sunday, matching `Calendar`) → the parts selected for it.
    @Binding var selection: [Int: Set<DayPart>]

    /// Drag-to-paint competes with a surrounding scroll view for the gesture. Hosts that
    /// scroll either opt out, or bind `isPainting` and disable scrolling while it's true.
    var allowsDrag = true
    var isPainting: Binding<Bool> = .constant(false)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Row height meets the 44pt minimum target; columns get whatever width is left, which on
    // the narrowest phone still clears 44pt.
    private let rowHeight: CGFloat = 46
    private let rowSpacing: CGFloat = 4
    private let columnSpacing: CGFloat = 6
    private let labelWidth: CGFloat = 72
    private let cornerRadius: CGFloat = 11

    @State private var gridWidth: CGFloat = 0
    /// What the current paint stroke is setting cells to, and which it has already visited —
    /// a stroke shouldn't flip the same cell twice as your finger wobbles.
    @State private var paintTarget: Bool?
    @State private var painted: Set<Int> = []

    private let calendar = Calendar.current

    /// Weekday numbers in the reader's own order — many locales start on Monday.
    private var weekdays: [Int] {
        (0..<7).map { ((calendar.firstWeekday - 1 + $0) % 7) + 1 }
    }

    private func initial(_ weekday: Int) -> String {
        calendar.veryShortWeekdaySymbols[weekday - 1]
    }

    private func name(_ weekday: Int) -> String {
        calendar.weekdaySymbols[weekday - 1]
    }

    private var today: Int { calendar.component(.weekday, from: Date()) }

    private var columnWidth: CGFloat {
        guard gridWidth > 0 else { return 0 }
        return (gridWidth - columnSpacing * 6) / 7
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            labelColumn
            dayColumns
        }
    }

    // MARK: - Left labels

    private var labelColumn: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            // Spacer matching the day-initial header so rows line up with their cells.
            Text(" ")
                .font(.caption2)
                .padding(.bottom, 6)

            ForEach(DayPart.allCases, id: \.self) { part in
                Button {
                    toggleRow(part)
                } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(part.shortName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        Text(part.timeRangeLabel)
                            .font(.caption2)
                            .foregroundColor(.stackSecondaryText)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(width: labelWidth, height: rowHeight, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(part.displayName)
                .accessibilityHint("Toggles \(part.displayName) on every day")
            }
        }
    }

    // MARK: - Grid

    private var dayColumns: some View {
        VStack(spacing: 6) {
            HStack(spacing: columnSpacing) {
                ForEach(weekdays, id: \.self) { weekday in
                    dayHeader(weekday)
                }
            }

            HStack(alignment: .top, spacing: columnSpacing) {
                ForEach(weekdays, id: \.self) { weekday in
                    dayColumn(weekday)
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { gridWidth = $0 }
            .coordinateSpace(name: "dayGrid")
            .gesture(allowsDrag ? paintGesture : nil)
        }
    }

    private func dayHeader(_ weekday: Int) -> some View {
        let isToday = weekday == today
        let isFull = selection[weekday]?.count == DayPart.allCases.count

        return Button {
            toggleColumn(weekday)
        } label: {
            VStack(spacing: 3) {
                Text(initial(weekday))
                    .font(.caption.weight(isToday ? .heavy : .semibold))
                    .foregroundColor(isToday ? .stackGreen : .stackSecondaryText)
                Circle()
                    .fill(isToday ? Color.stackGreen : .clear)
                    .frame(width: 3, height: 3)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name(weekday))
        .accessibilityValue(isFull ? "All day parts selected" : "")
        .accessibilityHint("Toggles the whole day")
    }

    private func dayColumn(_ weekday: Int) -> some View {
        ZStack(alignment: .top) {
            // Empty wells sit underneath; selected runs are painted over them as one shape.
            VStack(spacing: rowSpacing) {
                ForEach(DayPart.allCases, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.stackCardWhite)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .strokeBorder(Color.stackBorder, lineWidth: 1)
                        )
                        .frame(height: rowHeight)
                }
            }

            ForEach(runs(for: weekday), id: \.lowerBound) { run in
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.stackGreen)
                    .frame(height: height(of: run))
                    .offset(y: offset(of: run))
            }

            // Hit targets last so they sit above the paint.
            VStack(spacing: rowSpacing) {
                ForEach(DayPart.allCases, id: \.self) { part in
                    cellTarget(weekday: weekday, part: part)
                }
            }
        }
    }

    private func cellTarget(weekday: Int, part: DayPart) -> some View {
        let isOn = isOn(weekday, part)

        return Color.clear
            .frame(height: rowHeight)
            .contentShape(Rectangle())
            // With drag enabled a single gesture drives both tap and paint, so a Button here
            // would double-fire; the accessibility action keeps VoiceOver working either way.
            .onTapGesture { if !allowsDrag { toggle(weekday, part) } }
            .accessibilityElement()
            .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
            .accessibilityLabel("\(name(weekday)), \(part.displayName)")
            .accessibilityValue(isOn ? "Selected" : "Not selected")
            .accessibilityAction { toggle(weekday, part) }
    }

    // MARK: - Runs

    /// Contiguous stretches of selected parts, as index ranges into `DayPart.allCases`.
    private func runs(for weekday: Int) -> [ClosedRange<Int>] {
        let parts = selection[weekday] ?? []
        var result: [ClosedRange<Int>] = []
        var start: Int?

        for (index, part) in DayPart.allCases.enumerated() {
            if parts.contains(part) {
                if start == nil { start = index }
            } else if let began = start {
                result.append(began...(index - 1))
                start = nil
            }
        }
        if let began = start { result.append(began...(DayPart.allCases.count - 1)) }
        return result
    }

    private func height(of run: ClosedRange<Int>) -> CGFloat {
        let rows = CGFloat(run.count)
        return rows * rowHeight + (rows - 1) * rowSpacing
    }

    private func offset(of run: ClosedRange<Int>) -> CGFloat {
        CGFloat(run.lowerBound) * (rowHeight + rowSpacing)
    }

    // MARK: - Painting

    private var paintGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("dayGrid"))
            .onChanged { value in
                guard let cell = cell(at: value.location) else { return }
                let key = cell.weekday * 100 + cell.index
                guard !painted.contains(key) else { return }

                if paintTarget == nil {
                    paintTarget = !isOn(cell.weekday, cell.part)
                    isPainting.wrappedValue = true
                }
                painted.insert(key)
                set(cell.weekday, cell.part, to: paintTarget ?? true)
                Haptics.tap()
            }
            .onEnded { _ in
                paintTarget = nil
                painted.removeAll()
                isPainting.wrappedValue = false
            }
    }

    private func cell(at point: CGPoint) -> (weekday: Int, part: DayPart, index: Int)? {
        guard columnWidth > 0 else { return nil }
        let column = Int(point.x / (columnWidth + columnSpacing))
        let row = Int(point.y / (rowHeight + rowSpacing))
        guard weekdays.indices.contains(column), DayPart.allCases.indices.contains(row) else {
            return nil
        }
        return (weekdays[column], DayPart.allCases[row], row)
    }

    // MARK: - Mutation

    private func isOn(_ weekday: Int, _ part: DayPart) -> Bool {
        selection[weekday]?.contains(part) == true
    }

    private func animated(_ changes: () -> Void) {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.18, extraBounce: 0.1), changes)
    }

    private func set(_ weekday: Int, _ part: DayPart, to isOn: Bool) {
        animated {
            var parts = selection[weekday] ?? []
            if isOn { parts.insert(part) } else { parts.remove(part) }
            selection[weekday] = parts
        }
    }

    private func toggle(_ weekday: Int, _ part: DayPart) {
        Haptics.tap()
        set(weekday, part, to: !isOn(weekday, part))
    }

    /// Fills the day unless it's already full, in which case it clears — the same affordance
    /// reads as "all" or "none" depending on what you're looking at.
    private func toggleColumn(_ weekday: Int) {
        let all = Set(DayPart.allCases)
        let isFull = selection[weekday] == all
        Haptics.bump()
        animated { selection[weekday] = isFull ? [] : all }
    }

    private func toggleRow(_ part: DayPart) {
        let isFull = weekdays.allSatisfy { isOn($0, part) }
        Haptics.bump()
        animated {
            for weekday in weekdays {
                var parts = selection[weekday] ?? []
                if isFull { parts.remove(part) } else { parts.insert(part) }
                selection[weekday] = parts
            }
        }
    }
}

extension Dictionary where Key == Int, Value == Set<DayPart> {
    /// Flattens the grid into the windows `set-schedule` stores, merging touching parts so a
    /// morning-plus-early-afternoon tap becomes one 6am-3pm window rather than two.
    var scheduleWindows: [ScheduleService.ScheduleWindow] {
        keys.sorted().flatMap { weekday -> [ScheduleService.ScheduleWindow] in
            DayPart.mergedWindows(from: self[weekday] ?? []).map { window in
                // `user_schedules.day_of_week` is 0-based from Sunday; Calendar's is 1-based.
                ScheduleService.ScheduleWindow(
                    day_of_week: weekday - 1,
                    start_time: window.start,
                    end_time: window.end,
                    preferred_format: nil
                )
            }
        }
    }

    var hasAnySelection: Bool {
        contains { !$0.value.isEmpty }
    }

    /// Days with at least one part selected — the number worth reporting back.
    var selectedDayCount: Int {
        filter { !$0.value.isEmpty }.count
    }
}
