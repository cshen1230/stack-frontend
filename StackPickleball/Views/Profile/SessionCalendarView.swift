import SwiftUI

struct SessionCalendarView: View {
    let pastGames: [Game]
    let currentUserId: UUID?

    @State private var displayedMonth = Date()
    @State private var selectedDate: DateComponents?

    private let calendar = Calendar.current
    private let daysOfWeek = ["M", "T", "W", "T", "F", "S", "S"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    // MARK: - Computed

    private var gamesByDate: [DateComponents: [Game]] {
        Dictionary(grouping: pastGames) { game in
            calendar.dateComponents([.year, .month, .day], from: game.gameDatetime)
        }
    }

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    /// All day slots for the calendar grid (including leading blanks for alignment)
    private var calendarDays: [DateComponents?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }

        // weekday of the 1st: shift so Monday = 0
        let firstWeekday = (calendar.component(.weekday, from: firstOfMonth) + 5) % 7
        let blanks: [DateComponents?] = Array(repeating: nil, count: firstWeekday)

        let year = calendar.component(.year, from: displayedMonth)
        let month = calendar.component(.month, from: displayedMonth)

        let days: [DateComponents?] = range.map { day in
            DateComponents(year: year, month: month, day: day)
        }

        return blanks + days
    }

    private var selectedGames: [Game] {
        guard let sel = selectedDate else { return [] }
        return gamesByDate[sel] ?? []
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            calendarCard
            expandedSessionList
        }
    }

    // MARK: - Calendar Card

    private var calendarCard: some View {
        VStack(spacing: 14) {
            // Month header
            HStack {
                Button { shiftMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.stackGreen)
                }

                Spacer()

                Text(monthTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)

                Spacer()

                Button { shiftMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.stackGreen)
                }
            }
            .padding(.horizontal, 4)

            // Day-of-week header
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.stackGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)
                }
            }

            // Day grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, dc in
                    if let dc = dc {
                        dayCell(for: dc)
                    } else {
                        Color.clear
                            .frame(height: 36)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.black, lineWidth: 1)
        )
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.stackGreen)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.black, lineWidth: 1)
                )
                .offset(x: 3, y: 4)
        )
    }

    // MARK: - Day Cell

    private func dayCell(for dc: DateComponents) -> some View {
        let count = gamesByDate[dc]?.count ?? 0
        let isSelected = selectedDate == dc
        let today = calendar.dateComponents([.year, .month, .day], from: Date())
        let isToday = dc == today

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                if selectedDate == dc {
                    selectedDate = nil
                } else {
                    selectedDate = dc
                }
            }
        } label: {
            Text("\(dc.day ?? 0)")
                .font(.system(size: 15, weight: isToday ? .bold : .medium))
                .foregroundColor(isSelected ? .white : (count > 0 ? .black : .stackSecondaryText))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(backgroundForDay(count: count, isSelected: isSelected))
                )
        }
        .buttonStyle(.plain)
    }

    private func backgroundForDay(count: Int, isSelected: Bool) -> Color {
        if isSelected {
            return Color.stackGreen
        }
        switch count {
        case 0: return .clear
        case 1: return Color.stackGreen.opacity(0.25)
        case 2: return Color.stackGreen.opacity(0.50)
        default: return Color.stackGreen.opacity(0.75)
        }
    }

    // MARK: - Expanded Session List

    @ViewBuilder
    private var expandedSessionList: some View {
        if !selectedGames.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                if let date = calendar.date(from: selectedDate!) {
                    Text(date.formatted(.dateTime.month(.wide).day().year()))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.leading, 4)
                }

                ForEach(selectedGames) { game in
                    PastSessionCard(
                        game: game,
                        isHost: game.creatorId == currentUserId
                    )
                }
            }
            .padding(.top, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Helpers

    private func shiftMonth(by value: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
                displayedMonth = newMonth
                selectedDate = nil
            }
        }
    }
}
