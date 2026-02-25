import SwiftUI

struct CreateGameView: View {
    var sessionType: SessionType = .casual
    var onCreated: ((CreatedSessionInfo) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationManager: LocationManager
    @State private var viewModel = CreateGameViewModel()
    @State private var showingLocationPicker = false

    var body: some View {
        Form {
            Section("Game Details") {
                TextField("Session Name", text: $viewModel.sessionName)

                Button {
                    showingLocationPicker = true
                } label: {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.stackGreen)
                        if viewModel.selectedLatitude == nil {
                            Text("Choose Location")
                                .foregroundColor(.secondary)
                        } else {
                            Text(viewModel.locationName)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }

                if viewModel.selectedLatitude != nil {
                    TextField("Park / Venue Name", text: $viewModel.locationName)
                }
                DatePicker("Date & Time", selection: $viewModel.selectedDate, in: Date()...)

                HStack {
                    Text("Minimum DUPR")
                    Spacer()
                    TextField("0.0", text: Binding(
                        get: { String(format: "%.1f", viewModel.skillLevelMin) },
                        set: { viewModel.skillLevelMin = Double($0) ?? 0.0 }
                    ))
                    .multilineTextAlignment(.trailing)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .frame(width: 60)
                }

                Picker("Format", selection: $viewModel.gameFormat) {
                    ForEach(viewModel.availableFormats, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }

                Stepper("Players: \(viewModel.spotsAvailable)", value: $viewModel.spotsAvailable, in: 2...16)

                if viewModel.isRoundRobin {
                    Stepper("Rounds: \(viewModel.numRounds)", value: $viewModel.numRounds, in: 1...30)
                }
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
        .navigationTitle(viewModel.isRoundRobin ? "Create Round Robin" : "Create Game")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    Task {
                        let info = await viewModel.createGame(
                            lat: locationManager.latitude,
                            lng: locationManager.longitude
                        )
                        if let info {
                            onCreated?(info)
                        }
                    }
                }
                .fontWeight(.semibold)
                .disabled(viewModel.sessionName.isEmpty || viewModel.locationName.isEmpty || viewModel.isLoading)
            }
        }
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerView(
                userLatitude: locationManager.latitude,
                userLongitude: locationManager.longitude
            ) { name, lat, lng in
                viewModel.locationName = name
                viewModel.selectedLatitude = lat
                viewModel.selectedLongitude = lng
            }
        }
        .onAppear {
            viewModel.sessionType = sessionType
        }
    }
}

#Preview {
    NavigationStack {
        CreateGameView()
            .environmentObject(LocationManager.shared)
    }
}
