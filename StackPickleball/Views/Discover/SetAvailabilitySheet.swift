import SwiftUI

struct SetAvailabilitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationManager: LocationManager
    @Bindable var viewModel: DiscoverViewModel

    @State private var isAvailable: Bool
    @State private var note: String
    @State private var selectedHours: Int = 2
    @State private var selectedFormat: GameFormat? = nil
    @State private var isSaving = false

    private let durationOptions = [1, 2, 3, 4]
    private let formatOptions: [GameFormat?] = [nil, .singles, .doubles, .mixedDoubles, .drill]

    init(viewModel: DiscoverViewModel) {
        self.viewModel = viewModel
        _isAvailable = State(initialValue: viewModel.isCurrentUserAvailable)
        _note = State(initialValue: viewModel.currentUserNote ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Toggle
                Toggle("I'm available to play", isOn: $isAvailable)
                    .font(.system(size: 17, weight: .semibold))
                    .tint(.stackGreen)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                if isAvailable {
                    VStack(spacing: 16) {
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

                        // Duration picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Available for")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                ForEach(durationOptions, id: \.self) { hours in
                                    Button {
                                        selectedHours = hours
                                    } label: {
                                        Text("\(hours)h")
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
                    }
                    .padding(.horizontal, 16)
                }

                Spacer()

                // Action button
                if viewModel.isCurrentUserAvailable && !isAvailable {
                    // User is turning off availability
                    Button {
                        isSaving = true
                        Task {
                            await viewModel.clearAvailability()
                            isSaving = false
                            dismiss()
                        }
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("Stop Availability")
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                    .disabled(isSaving)
                    .padding(.horizontal, 16)
                } else if isAvailable {
                    Button {
                        isSaving = true
                        Task {
                            let until = Date().addingTimeInterval(TimeInterval(selectedHours * 3600))
                            await viewModel.setAvailability(
                                note: note.isEmpty ? nil : note,
                                availableUntil: until,
                                preferredFormat: selectedFormat,
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
                            Text(viewModel.isCurrentUserAvailable ? "Update Availability" : "Go Available")
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
                }
            }
            .padding(.bottom, 16)
            .navigationTitle("Availability")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
