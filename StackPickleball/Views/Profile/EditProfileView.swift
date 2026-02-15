import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProfileViewModel

    @State private var name: String = ""
    @State private var duprRating: String = ""
    @State private var location: String = ""
    @State private var preferredSide: PlayingSide = .forehand

    var body: some View {
        NavigationStack {
            Form {
                Section("Personal Info") {
                    TextField("Name", text: $name)
                    TextField("Location", text: $location)
                }

                Section("Pickleball Info") {
                    TextField("DUPR Rating", text: $duprRating)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif

                    Picker("Preferred Side", selection: $preferredSide) {
                        Text("Forehand").tag(PlayingSide.forehand)
                        Text("Backhand").tag(PlayingSide.backhand)
                    }
                }
            }
            .navigationTitle("Edit Profile")
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
                    Button("Save") {
                        if var user = viewModel.user {
                            user.name = name
                            user.location = location.isEmpty ? nil : location
                            user.duprRating = Double(duprRating)
                            user.preferredSide = preferredSide
                            Task {
                                await viewModel.updateProfile(user)
                            }
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let user = viewModel.user {
                    name = user.name
                    duprRating = user.duprRating.map { String(format: "%.1f", $0) } ?? ""
                    location = user.location ?? ""
                    preferredSide = user.preferredSide ?? .forehand
                }
            }
        }
    }
}
