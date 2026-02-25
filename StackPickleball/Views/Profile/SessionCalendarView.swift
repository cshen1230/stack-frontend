import SwiftUI

struct SessionCalendarView: View {
    let pastGames: [Game]
    let currentUserId: UUID?

    @State private var displayedMonth = Date()
    @State private var selectedDate: DateComponents?
    @State private var selectedGame: Game?

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

    private var calendarDays: [DateComponents?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }

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

            if !selectedGames.isEmpty {
                expandedSessionList
            }
        }
        .sheet(item: $selectedGame) { game in
            PastSessionDetailSheet(game: game, isHost: game.creatorId == currentUserId)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
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
            LazyVGrid(columns: columns, spacing: 6) {
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
        let hasSessions = count > 0

        return Group {
            if hasSessions {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedDate = selectedDate == dc ? nil : dc
                    }
                } label: {
                    dayCellLabel(day: dc.day ?? 0, count: count, isSelected: isSelected, isToday: isToday)
                }
                .buttonStyle(.plain)
            } else {
                dayCellLabel(day: dc.day ?? 0, count: 0, isSelected: false, isToday: isToday)
            }
        }
        .frame(height: 36)
    }

    private func dayCellLabel(day: Int, count: Int, isSelected: Bool, isToday: Bool) -> some View {
        Text("\(day)")
            .font(.system(size: 15, weight: (isToday || count > 0) ? .bold : .medium))
            .foregroundColor(dayTextColor(count: count, isSelected: isSelected, isToday: isToday))
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(dayBackgroundColor(count: count, isSelected: isSelected))
            )
    }

    private func dayTextColor(count: Int, isSelected: Bool, isToday: Bool) -> Color {
        if isSelected || count > 0 { return .white }
        if isToday { return .stackGreen }
        return .stackSecondaryText
    }

    private func dayBackgroundColor(count: Int, isSelected: Bool) -> Color {
        if isSelected { return Color.stackGreen }
        if count == 0 { return .clear }
        let opacity = min(1.0, 0.2 + Double(count) * 0.2)
        return Color.stackGreen.opacity(opacity)
    }

    // MARK: - Expanded Session List

    private var expandedSessionList: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let sel = selectedDate, let date = calendar.date(from: sel) {
                Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.leading, 4)
            }

            ForEach(selectedGames) { game in
                sessionRow(game: game)
                    .onTapGesture {
                        selectedGame = game
                    }
            }
        }
        .padding(.top, 16)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Inline Session Row

    private func sessionRow(game: Game) -> some View {
        let isHost = game.creatorId == currentUserId

        return HStack(spacing: 12) {
            // Format color bar
            RoundedRectangle(cornerRadius: 3)
                .fill(game.gameFormat.accentColor)
                .frame(width: 4, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(game.sessionName ?? game.creatorDisplayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if isHost {
                        HStack(spacing: 2) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 9))
                            Text("Host")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.orange)
                    }
                }

                HStack(spacing: 8) {
                    Text(game.gameDatetime, format: .dateTime.hour().minute())
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    Text(game.gameFormat.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.stackGreen)

                    Text("\(game.spotsFilled)/\(game.spotsAvailable)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    if let location = game.locationName {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin")
                                .font(.system(size: 10))
                            Text(location)
                                .lineLimit(1)
                        }
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.stackSecondaryText)
        }
        .padding(12)
        .background(Color.stackCardWhite)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
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

// MARK: - Past Session Detail Sheet

private struct PastSessionDetailSheet: View {
    let game: Game
    let isHost: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(game.gameFormat.accentColor)
                        .frame(height: 4)
                        .padding(.horizontal, 40)
                        .padding(.top, 4)

                    VStack(spacing: 8) {
                        Text(game.sessionName ?? game.creatorDisplayName)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 8) {
                            Text(game.gameFormat.displayName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(game.gameFormat.accentColor)
                                .cornerRadius(8)

                            if isHost {
                                HStack(spacing: 4) {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 11))
                                    Text("Host")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.orange)
                                .cornerRadius(8)
                            }
                        }
                    }

                    VStack(spacing: 14) {
                        detailRow(icon: "calendar", label: "Date",
                                  value: game.gameDatetime.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year()))

                        Divider()

                        detailRow(icon: "clock", label: "Time",
                                  value: game.gameDatetime.formatted(.dateTime.hour().minute()))

                        if let location = game.locationName {
                            Divider()
                            detailRow(icon: "mappin.circle", label: "Location", value: location)
                        }

                        Divider()

                        detailRow(icon: "person.2", label: "Players",
                                  value: "\(game.spotsFilled)/\(game.spotsAvailable)")

                        if let min = game.skillLevelMin {
                            Divider()
                            detailRow(icon: "trophy", label: "Min DUPR",
                                      value: "\(String(format: "%.1f", min))+")
                        }

                        if let desc = game.description, !desc.isEmpty {
                            Divider()
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Image(systemName: "text.alignleft")
                                        .font(.system(size: 14))
                                        .foregroundColor(.stackSecondaryText)
                                        .frame(width: 24)
                                    Text("Notes")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.stackSecondaryText)
                                }
                                Text(desc)
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary)
                                    .padding(.leading, 32)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.stackCardWhite)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.stackBorder, lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color.stackBackground)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
            }
        }
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.stackSecondaryText)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.stackSecondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}
