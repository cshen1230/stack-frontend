import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    var viewModel: ProfileViewModel

    @State private var firstName = ""
    @State private var middleName = ""
    @State private var lastName = ""
    @State private var username = ""
    @State private var duprRating = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarImage: Image?
    @State private var avatarData: Data?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            if let avatarImage {
                                avatarImage
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 90, height: 90)
                                    .clipShape(Circle())
                            } else if let avatarUrl = viewModel.user?.avatarUrl, let url = URL(string: avatarUrl) {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    avatarPlaceholder
                                }
                                .frame(width: 90, height: 90)
                                .clipShape(Circle())
                            } else {
                                avatarPlaceholder
                            }
                        }
                        Spacer()
                    }
                    HStack {
                        Spacer()
                        Text("Change Photo")
                            .font(.footnote)
                            .foregroundColor(.accentColor)
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
                .onChange(of: selectedPhoto) {
                    Task {
                        if let data = try? await selectedPhoto?.loadTransferable(type: Data.self) {
                            avatarData = data
                            #if canImport(UIKit)
                            if let uiImage = UIImage(data: data) {
                                avatarImage = Image(uiImage: uiImage)
                            }
                            #endif
                        }
                    }
                }

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
                            isSaving = true
                            var uploadedAvatarUrl: String?
                            if let avatarData, let userId = viewModel.user?.id {
                                // Compress to JPEG
                                #if canImport(UIKit)
                                let jpeg = UIImage(data: avatarData)?.jpegData(compressionQuality: 0.8) ?? avatarData
                                #else
                                let jpeg = avatarData
                                #endif
                                uploadedAvatarUrl = try? await ProfileService.uploadAvatar(userId: userId, imageData: jpeg)
                            }
                            await viewModel.updateProfile(
                                firstName: firstName.isEmpty ? nil : firstName,
                                lastName: lastName.isEmpty ? nil : lastName,
                                middleName: middleName,
                                username: username.isEmpty ? nil : username,
                                duprRating: Double(duprRating),
                                avatarUrl: uploadedAvatarUrl
                            )
                            isSaving = false
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving)
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

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 90, height: 90)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            )
    }
}
