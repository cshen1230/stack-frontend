import SwiftUI

struct CreateGameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationManager: LocationManager
    @State private var viewModel = CreateGameViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Game Details") {
                    TextField("Session Name", text: $viewModel.sessionName)
                    TextField("Location Name", text: $viewModel.locationName)
                    DatePicker("Date & Time", selection: $viewModel.selectedDate, in: Date()...)

                    HStack {
                        Text("DUPR Range")
                        Spacer()
                        Text("\(String(format: "%.1f", viewModel.skillLevelMin)) - \(String(format: "%.1f", viewModel.skillLevelMax))")
                            .foregroundColor(.secondary)
                    }

                    Picker("Format", selection: $viewModel.gameFormat) {
                        ForEach(GameFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }

                    Stepper("Spots: \(viewModel.spotsAvailable)", value: $viewModel.spotsAvailable, in: 1...16)
                }

                Section("Additional Info") {
                    TextField("Description (optional)", text: $viewModel.description, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Create Game")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await viewModel.createGame(
                                lat: locationManager.latitude,
                                lng: locationManager.longitude
                            )
                            if viewModel.showingSuccess {
                                dismiss()
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.sessionName.isEmpty || viewModel.locationName.isEmpty || viewModel.isLoading)
                }
            }
        }
    }
}

#Preview {
    CreateGameView()
        .environmentObject(LocationManager.shared)
}
