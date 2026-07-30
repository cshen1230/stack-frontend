import SwiftUI

/// Horizontal day picker above the planner. Each day is its own calendar, so switching days
/// swaps which availability you're looking at.
struct DayStrip: View {
    @Binding var selectedDay: Date
    /// How many days forward you can plan.
    var dayCount: Int = 14
    /// Days that have at least one friend free, for the dot under the label.
    var daysWithAvailability: Set<Date> = []

    private let calendar = Calendar.current

    private var days: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<dayCount).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(days, id: \.self) { day in
                        dayChip(day)
                            .id(day)
                    }
                }
                .padding(.horizontal, 16)
            }
            .onAppear {
                proxy.scrollTo(calendar.startOfDay(for: selectedDay), anchor: .leading)
            }
        }
    }

    private func dayChip(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let hasAvailability = daysWithAvailability.contains(calendar.startOfDay(for: day))

        return Button {
            selectedDay = day
        } label: {
            VStack(spacing: 2) {
                Text(weekdayLabel(day))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isSelected ? .white.opacity(0.85) : .stackSecondaryText)

                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(isSelected ? .white : .primary)

                Circle()
                    .fill(dotColor(isSelected: isSelected, hasAvailability: hasAvailability))
                    .frame(width: 5, height: 5)
            }
            .frame(width: 48)
            .padding(.vertical, 8)
            .background(isSelected ? Color.stackGreen : Color.stackCardWhite)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color.stackBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func dotColor(isSelected: Bool, hasAvailability: Bool) -> Color {
        guard hasAvailability else { return .clear }
        return isSelected ? .white : .stackGreen
    }

    /// "Today" for the first chip, otherwise the abbreviated weekday.
    private func weekdayLabel(_ day: Date) -> String {
        if calendar.isDateInToday(day) { return "Today" }
        return day.formatted(.dateTime.weekday(.abbreviated))
    }
}
