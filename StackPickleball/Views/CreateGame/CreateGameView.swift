import SwiftUI

struct CreateGameView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CreateGameViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Game Details") {
                    TextField("Location", text: $viewModel.location)
                    DatePicker("Date & Time", selection: $viewModel.selectedDate)

                    HStack {
                        Text("DUPR Range")
                        Spacer()
                        Text("\(String(format: "%.1f", viewModel.skillLevelMin)) - \(String(format: "%.1f", viewModel.skillLevelMax))")
                            .foregroundColor(.secondary)
                    }

                    Picker("Game Type", selection: $viewModel.gameType) {
                        Text("Singles").tag(GameType.singles)
                        Text("Doubles").tag(GameType.doubles)
                    }

                    Picker("Visibility", selection: $viewModel.visibility) {
                        Text("Public").tag(GameVisibility.publicGame)
                        Text("Private").tag(GameVisibility.privateGame)
                    }
                }

                Section("Additional Info") {
                    TextField("Notes (optional)", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Create New Game")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            // TODO: Get current user ID and name
                            await viewModel.createGame(hostId: UUID(), hostName: "Current User")
                            if viewModel.showingSuccess {
                                dismiss()
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.location.isEmpty)
                }
            }
        }
    }
}

#Preview {
    CreateGameView()
}
