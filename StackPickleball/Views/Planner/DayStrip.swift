import SwiftUI

/// One week of days above the planner, with arrows to step weeks.
///
/// This used to be a horizontally scrolling run of fourteen chips. Two things were wrong with
/// that: a scroll view whose content doesn't fill the screen leaves the row hanging off one
/// edge rather than sitting in the layout, and a horizontal scroll nested inside a vertical one
/// costs a gesture to discover something as ordinary as "next Tuesday". A week is a unit people
/// already think in, and seven chips fit across a phone without scrolling at all — so the row
/// can just divide the width, which is also what makes it land centred.
struct DayStrip: View {
    @Binding var selectedDay: Date
    /// Weekdays (1 = Sunday, matching `Calendar`) somebody plays on, for the dot under the
    /// number. Availability is recurring by weekday, so this is the form it already has —
    /// resolving it to concrete dates first only to look them up again is a step backwards.
    var playedWeekdays: Set<Int> = []
    /// How far ahead planning is allowed. Past this, the forward arrow disables.
    var weeksAhead: Int = 8

    private let calendar = Calendar.current

    /// The first day of the week `selectedDay` falls in, in the reader's own week ordering.
    private var weekStart: Date {
        calendar.dateInterval(of: .weekOfYear, for: selectedDay)?.start
            ?? calendar.startOfDay(for: selectedDay)
    }

    private var days: [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private var today: Date { calendar.startOfDay(for: Date()) }

    private var thisWeekStart: Date {
        calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
    }

    /// You can't plan a session that has already happened, so there's nothing behind this week.
    private var canGoBack: Bool { weekStart > thisWeekStart }

    private var canGoForward: Bool {
        guard let limit = calendar.date(byAdding: .weekOfYear, value: weeksAhead, to: thisWeekStart)
        else { return false }
        return weekStart < limit
    }

    var body: some View {
        VStack(spacing: 10) {
            header
            row
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 0) {
            stepButton(direction: -1, symbol: "chevron.left", enabled: canGoBack)

            Spacer(minLength: 0)

            VStack(spacing: 1) {
                Text(weekLabel)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                if !isCurrentWeek {
                    Text(relativeWeekLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.stackSecondaryText)
                }
            }
            .animation(Motion.content, value: weekLabel)

            Spacer(minLength: 0)

            stepButton(direction: 1, symbol: "chevron.right", enabled: canGoForward)
        }
    }

    private func stepButton(direction: Int, symbol: String, enabled: Bool) -> some View {
        Button {
            step(direction)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(enabled ? .stackGreen : .stackSecondaryText.opacity(0.35))
                .frame(width: 32, height: 32)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(direction < 0 ? "Previous week" : "Next week")
    }

    /// Steps a week and lands on a day rather than a week — the planner below always has a day
    /// selected, so leaving that stale would show last week's calendar under this week's chips.
    private func step(_ direction: Int) {
        guard let newStart = calendar.date(byAdding: .weekOfYear, value: direction, to: weekStart)
        else { return }
        Haptics.tap()
        withAnimation(Motion.state) {
            // Landing on today keeps "this week" meaning today rather than Sunday.
            selectedDay = calendar.isDate(newStart, equalTo: thisWeekStart, toGranularity: .weekOfYear)
                ? today
                : newStart
        }
    }

    // MARK: - Row

    private var row: some View {
        HStack(spacing: 6) {
            ForEach(days, id: \.self) { day in
                dayChip(day)
            }
        }
    }

    private func dayChip(_ day: Date) -> some View {
        let startOfDay = calendar.startOfDay(for: day)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isPast = startOfDay < today
        let hasAvailability = playedWeekdays.contains(calendar.component(.weekday, from: day))

        return Button {
            Haptics.tap()
            withAnimation(Motion.state) { selectedDay = day }
        } label: {
            VStack(spacing: 3) {
                Text(weekdayLabel(day))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(labelColor(isSelected: isSelected, isPast: isPast))

                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(numberColor(isSelected: isSelected, isPast: isPast))

                Circle()
                    .fill(dotColor(isSelected: isSelected, isPast: isPast, hasAvailability: hasAvailability))
                    .frame(width: 5, height: 5)
            }
            // maxWidth rather than a fixed width: seven equal shares of whatever space there
            // is, which is what stops the row drifting off-centre on any given screen.
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(chipBackground(isSelected: isSelected, isPast: isPast))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isPast)
        .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func chipBackground(isSelected: Bool, isPast: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isSelected ? Color.stackGreen : Color(.secondarySystemBackground))
            .opacity(isPast ? 0.5 : 1)
    }

    private func labelColor(isSelected: Bool, isPast: Bool) -> Color {
        if isSelected { return .white.opacity(0.85) }
        return isPast ? .stackSecondaryText.opacity(0.4) : .stackSecondaryText
    }

    private func numberColor(isSelected: Bool, isPast: Bool) -> Color {
        if isSelected { return .white }
        return isPast ? .secondary.opacity(0.4) : .primary
    }

    private func dotColor(isSelected: Bool, isPast: Bool, hasAvailability: Bool) -> Color {
        guard hasAvailability, !isPast else { return .clear }
        return isSelected ? .white : .stackGreen
    }

    // MARK: - Labels

    /// "Today" for today's chip, otherwise the abbreviated weekday.
    private func weekdayLabel(_ day: Date) -> String {
        if calendar.isDateInToday(day) { return "Today" }
        return day.formatted(.dateTime.weekday(.abbreviated))
    }

    private var isCurrentWeek: Bool {
        calendar.isDate(weekStart, equalTo: thisWeekStart, toGranularity: .weekOfYear)
    }

    /// "Aug 3 – 9", or "Aug 28 – Sep 3" when the week straddles a month.
    private var weekLabel: String {
        guard let last = days.last else { return "" }
        let sameMonth = calendar.isDate(weekStart, equalTo: last, toGranularity: .month)
        let start = weekStart.formatted(.dateTime.month(.abbreviated).day())
        let end = sameMonth
            ? "\(calendar.component(.day, from: last))"
            : last.formatted(.dateTime.month(.abbreviated).day())
        return "\(start) – \(end)"
    }

    private var relativeWeekLabel: String {
        let weeks = calendar.dateComponents([.weekOfYear], from: thisWeekStart, to: weekStart).weekOfYear ?? 0
        if weeks == 1 { return "Next week" }
        return "In \(weeks) weeks"
    }
}
