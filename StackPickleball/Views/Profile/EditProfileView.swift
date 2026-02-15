import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    var viewModel: ProfileViewModel

    @State private var firstName = ""
    @State private var middleName = ""
    @State private var lastName = ""
    @State private var username = ""
    @State private var duprRating = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                    TextField("Middle Name (optional)", text: $middleName)
                        .textContentType(.middleName)
                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                }

                Section("Account") {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                }

                Section("Pickleball") {
                    TextField("DUPR Rating", text: $duprRating)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
            }
            .navigationTitle("Edit Profile")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.updateProfile(
                                firstName: firstName.isEmpty ? nil : firstName,
                                lastName: lastName.isEmpty ? nil : lastName,
                                middleName: middleName,
                                username: username.isEmpty ? nil : username,
                                duprRating: Double(duprRating),
                                avatarUrl: nil
                            )
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let user = viewModel.user {
                    firstName = user.firstName
                    middleName = user.middleName ?? ""
                    lastName = user.lastName
                    username = user.username
                    duprRating = user.duprRating.map { String(format: "%.1f", $0) } ?? ""
                }
            }
        }
    }
}
