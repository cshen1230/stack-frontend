import SwiftUI

/// The whole availability editor: tap the parts of each day you usually play. One grid, used
/// both at onboarding and later from Profile, so there's a single way to express this.
struct DayPartGrid: View {
    /// Weekday (1 = Sunday, matching `Calendar`) → the parts selected for it.
    @Binding var selection: [Int: Set<DayPart>]

    private let weekdays = Array(1...7)
    private let dayInitials = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(spacing: 8) {
            header

            ForEach(DayPart.allCases, id: \.self) { part in
                row(for: part)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("")
                .frame(width: 74, alignment: .leading)

            ForEach(weekdays, id: \.self) { weekday in
                Text(dayInitials[weekday - 1])
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.stackSecondaryText)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func row(for part: DayPart) -> some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(part.shortName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                Text(part.timeRangeLabel)
                    .font(.system(size: 10))
                    .foregroundColor(.stackSecondaryText)
            }
            .frame(width: 74, alignment: .leading)

            ForEach(weekdays, id: \.self) { weekday in
                cell(weekday: weekday, part: part)
            }
        }
    }

    private func cell(weekday: Int, part: DayPart) -> some View {
        let isOn = selection[weekday]?.contains(part) == true

        return Button {
            var parts = selection[weekday] ?? []
            if parts.contains(part) { parts.remove(part) } else { parts.insert(part) }
            selection[weekday] = parts
        } label: {
            RoundedRectangle(cornerRadius: 8)
                .fill(isOn ? Color.stackGreen : Color.stackCardWhite)
                .frame(height: 34)
                .frame(maxWidth: .infinity)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isOn ? Color.clear : Color.stackBorder, lineWidth: 1)
                )
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .opacity(isOn ? 1 : 0)
                )
        }
        .buttonStyle(.plain)
    }
}

extension Dictionary where Key == Int, Value == Set<DayPart> {
    /// Flattens the grid into the windows `set-schedule` stores, merging touching parts so a
    /// morning-plus-early-afternoon tap becomes one 6am–3pm window rather than two.
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
}
