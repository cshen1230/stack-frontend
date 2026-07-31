import SwiftUI

/// The whole availability editor: tap the times of day you usually play.
///
/// Each row carries its own colour — sunrise gold, midday sky, golden hour, dusk indigo — so a
/// cell says which part of the day it belongs to even when it's empty. A grid of identical
/// white boxes says nothing until you trace it back to a label on the far left, and at 28 boxes
/// that's a lot of tracing.
struct DayPartGrid: View {
    /// Weekday (1 = Sunday, matching `Calendar`) → the parts selected for it.
    @Binding var selection: [Int: Set<DayPart>]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Rows clear the 44pt minimum target; columns take the width that's left, which on the
    // narrowest phone still clears 44pt.
    private let rowHeight: CGFloat = 46
    private let rowSpacing: CGFloat = 6
    private let columnSpacing: CGFloat = 6
    private let labelWidth: CGFloat = 78
    private let cornerRadius: CGFloat = 10

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

    var body: some View {
        VStack(spacing: rowSpacing) {
            headerRow
            ForEach(DayPart.allCases, id: \.self) { part in
                row(for: part)
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: columnSpacing) {
            Color.clear.frame(width: labelWidth, height: 22)

            ForEach(weekdays, id: \.self) { weekday in
                dayHeader(weekday)
            }
        }
    }

    private func dayHeader(_ weekday: Int) -> some View {
        let isToday = weekday == today
        let isFull = selection[weekday]?.count == DayPart.allCases.count

        return Button {
            toggleColumn(weekday)
        } label: {
            Text(initial(weekday))
                .font(.footnote.weight(isToday ? .heavy : .semibold))
                .foregroundColor(isToday ? .stackGreen : .stackSecondaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name(weekday))
        .accessibilityValue(isFull ? "All times selected" : "")
        .accessibilityHint("Selects or clears the whole day")
    }

    // MARK: - Rows

    private func row(for part: DayPart) -> some View {
        HStack(spacing: columnSpacing) {
            rowLabel(part)

            ForEach(weekdays, id: \.self) { weekday in
                cell(weekday: weekday, part: part)
            }
        }
    }

    private func rowLabel(_ part: DayPart) -> some View {
        Button {
            toggleRow(part)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: part.systemImage)
                    .font(.footnote)
                    .foregroundColor(part.color)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 0) {
                    Text(part.shortName)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.primary)
                    Text(part.timeRangeLabel)
                        .font(.caption2)
                        .foregroundColor(.stackSecondaryText)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: labelWidth, height: rowHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(part.displayName)
        .accessibilityHint("Selects or clears this time on every day")
    }

    private func cell(weekday: Int, part: DayPart) -> some View {
        let isOn = isOn(weekday, part)

        return Button {
            toggle(weekday, part)
        } label: {
            RoundedRectangle(cornerRadius: cornerRadius)
                // Full strength when chosen, a wash of the same hue when not — so the row
                // still reads, and on/off is a lightness difference rather than only a colour
                // one, which keeps it legible without relying on hue.
                .fill(part.color.opacity(isOn ? 1 : 0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(part.color.opacity(isOn ? 0 : 0.30), lineWidth: 1)
                )
                .frame(height: rowHeight)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name(weekday)), \(part.displayName)")
        .accessibilityValue(isOn ? "Selected" : "Not selected")
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Mutation

    private func isOn(_ weekday: Int, _ part: DayPart) -> Bool {
        selection[weekday]?.contains(part) == true
    }

    private func animated(_ changes: () -> Void) {
        withAnimation(reduceMotion ? nil : Motion.state, changes)
    }

    private func toggle(_ weekday: Int, _ part: DayPart) {
        Haptics.tap()
        animated {
            var parts = selection[weekday] ?? []
            if parts.contains(part) { parts.remove(part) } else { parts.insert(part) }
            selection[weekday] = parts
        }
    }

    /// Fills the day unless it's already full, in which case it clears — the same control reads
    /// as "all" or "none" depending on what you're looking at.
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
