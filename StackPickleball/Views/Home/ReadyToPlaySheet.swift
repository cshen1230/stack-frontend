import SwiftUI

struct ReadyToPlaySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationManager: LocationManager
    @Bindable var viewModel: HomeViewModel

    @State private var fromOption: FromOption = .now
    @State private var customFromTime: Date = Date()
    @State private var selectedHours: Int = 2
    @State private var selectedFormat: GameFormat? = nil
    @State private var note: String = ""
    @State private var isSaving = false

    enum FromOption: String, CaseIterable {
        case now = "Right now"
        case inOneHour = "In 1 hour"
        case custom = "Pick a date & time"
    }

    private let durationOptions = [1, 2, 3, 4]
    private let formatOptions: [GameFormat?] = [nil, .singles, .doubles, .mixedDoubles, .drill]

    private var fromDate: Date {
        switch fromOption {
        case .now: return Date()
        case .inOneHour: return Date().addingTimeInterval(3600)
        case .custom: return customFromTime
        }
    }

    private var untilDate: Date {
        fromDate.addingTimeInterval(TimeInterval(selectedHours * 3600))
    }

    private var untilDateLabel: String {
        if Calendar.current.isDateInToday(untilDate) {
            return untilDate.formatted(date: .omitted, time: .shortened)
        }
        return untilDate.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Starting time
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Starting")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            ForEach(FromOption.allCases, id: \.self) { option in
                                Button {
                                    fromOption = option
                                } label: {
                                    Text(option.rawValue)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(fromOption == option ? .white : .primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity)
                                        .background(fromOption == option ? Color.stackGreen : Color.stackBackground)
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(fromOption == option ? Color.clear : Color.stackBorder, lineWidth: 1)
                                        )
                                }
                            }
                        }

                        if fromOption == .custom {
                            DatePicker("From", selection: $customFromTime, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                                .padding(.top, 4)
                        }
                    }

                    // Duration
                    VStack(alignment: .leading, spacing: 6) {
                        Text("For how long?")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            ForEach(durationOptions, id: \.self) { hours in
                                Button {
                                    selectedHours = hours
                                } label: {
                                    Text("+\(hours)h")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(selectedHours == hours ? .white : .primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(selectedHours == hours ? Color.stackGreen : Color.stackBackground)
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(selectedHours == hours ? Color.clear : Color.stackBorder, lineWidth: 1)
                                        )
                                }
                            }
                        }

                        // Show computed end time
                        Text("Until \(untilDateLabel)")
                            .font(.system(size: 13))
                            .foregroundColor(.stackSecondaryText)
                            .padding(.top, 2)
                    }

                    // Format picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Format (optional)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(formatOptions, id: \.self) { format in
                                    Button {
                                        selectedFormat = format
                                    } label: {
                                        Text(format?.displayName ?? "Any")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(selectedFormat == format ? .white : .primary)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(selectedFormat == format ? Color.stackGreen : Color.stackBackground)
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(selectedFormat == format ? Color.clear : Color.stackBorder, lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }
                    }

                    // Note field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What are you looking for?")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        TextField("Looking for doubles partner, want to drill serves, etc.", text: $note, axis: .vertical)
                            .lineLimit(2...4)
                            .padding(12)
                            .background(Color.stackBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.stackBorder, lineWidth: 1)
                            )
                    }

                    // Info text
                    HStack(spacing: 6) {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 13))
                            .foregroundColor(.stackSecondaryText)
                        Text("Your friends will be notified that you're ready to play")
                            .font(.system(size: 13))
                            .foregroundColor(.stackSecondaryText)
                    }
                    .padding(.top, 4)

                    Spacer(minLength: 20)

                    // Broadcast button
                    Button {
                        isSaving = true
                        Task {
                            await viewModel.broadcastReady(
                                from: fromDate,
                                until: untilDate,
                                format: selectedFormat,
                                note: note.isEmpty ? nil : note,
                                lat: locationManager.latitude,
                                lng: locationManager.longitude
                            )
                            isSaving = false
                            dismiss()
                        }
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("Broadcast Ready to Play")
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.stackGreen)
                        .cornerRadius(12)
                    }
                    .disabled(isSaving)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .navigationTitle("Ready to Play")
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
}
