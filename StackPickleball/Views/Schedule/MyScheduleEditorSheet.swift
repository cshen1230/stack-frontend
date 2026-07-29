import SwiftUI

struct MyScheduleEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ScheduleViewModel

    @State private var selectedDay: Int = {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday - 1
    }()
    @State private var isSaving = false

    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let formatOptions: [GameFormat?] = [nil, .singles, .doubles, .mixedDoubles, .drill]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Day selector
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { day in
                        Button {
                            selectedDay = day
                        } label: {
                            Text(dayNames[day])
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(selectedDay == day ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(selectedDay == day ? Color.stackGreen : Color.stackBackground)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedDay == day ? Color.clear : Color.stackBorder, lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.horizontal, 16)

                // Windows for selected day
                let windows = viewModel.editingWindows[selectedDay] ?? []

                if windows.isEmpty {
                    VStack(spacing: 8) {
                        Text("No windows set for \(dayNames[selectedDay])")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(windows.enumerated()), id: \.element.id) { index, window in
                                windowRow(dayIndex: selectedDay, windowIndex: index, window: window)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                // Add window button
                Button {
                    let calendar = Calendar.current
                    var startComponents = calendar.dateComponents([.year, .month, .day], from: Date())
                    startComponents.hour = 18
                    startComponents.minute = 0
                    var endComponents = startComponents
                    endComponents.hour = 20

                    let draft = ScheduleWindowDraft(
                        startTime: calendar.date(from: startComponents) ?? Date(),
                        endTime: calendar.date(from: endComponents) ?? Date()
                    )
                    viewModel.editingWindows[selectedDay, default: []].append(draft)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 15))
                        Text("Add Window")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.stackGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.stackGreen.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 16)

                Spacer()

                // Save button
                Button {
                    isSaving = true
                    Task {
                        await viewModel.saveSchedule()
                        isSaving = false
                        dismiss()
                    }
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Save Schedule")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.stackGreen)
                    .cornerRadius(12)
                }
                .disabled(isSaving)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .navigationTitle("My Schedule")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func windowRow(dayIndex: Int, windowIndex: Int, window: ScheduleWindowDraft) -> some View {
        VStack(spacing: 10) {
            HStack {
                DatePicker("Start", selection: Binding(
                    get: { window.startTime },
                    set: { viewModel.editingWindows[dayIndex]?[windowIndex].startTime = $0 }
                ), displayedComponents: .hourAndMinute)
                .labelsHidden()

                Text("to")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                DatePicker("End", selection: Binding(
                    get: { window.endTime },
                    set: { viewModel.editingWindows[dayIndex]?[windowIndex].endTime = $0 }
                ), displayedComponents: .hourAndMinute)
                .labelsHidden()

                Spacer()

                Button {
                    viewModel.editingWindows[dayIndex]?.remove(at: windowIndex)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                }
            }

            // Format picker for this window
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(formatOptions, id: \.self) { format in
                        Button {
                            viewModel.editingWindows[dayIndex]?[windowIndex].preferredFormat = format
                        } label: {
                            Text(format?.displayName ?? "Any")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(window.preferredFormat == format ? .white : .primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(window.preferredFormat == format ? Color.stackGreen : Color.stackBackground)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(window.preferredFormat == format ? Color.clear : Color.stackBorder, lineWidth: 1)
                                )
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.stackCardWhite)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.stackBorder, lineWidth: 1)
        )
    }
}
