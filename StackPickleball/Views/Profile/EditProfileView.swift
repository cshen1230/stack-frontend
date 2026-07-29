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
    @State private var duprConnected = false

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

                Section("DUPR") {
                    if duprConnected {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.stackGreen)
                            Text("DUPR Verified")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.stackGreen)
                        }

                        if let singles = viewModel.user?.duprSinglesRating {
                            HStack {
                                Text("Singles")
                                    .foregroundColor(.stackSecondaryText)
                                Spacer()
                                Text(String(format: "%.2f", singles))
                            }
                        }

                        if let doubles = viewModel.user?.duprDoublesRating {
                            HStack {
                                Text("Doubles")
                                    .foregroundColor(.stackSecondaryText)
                                Spacer()
                                Text(String(format: "%.2f", doubles))
                            }
                        }
                    } else {
                        DUPRConnectView(
                            onConnected: { _ in
                                duprConnected = true
                                Task { await viewModel.loadProfile() }
                            },
                            allowSkip: false,
                            isConnected: false
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
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
                                #if canImport(UIKit)
                                let jpeg = UIImage(data: avatarData)?.jpegData(compressionQuality: 0.8) ?? avatarData
                                #else
                                let jpeg = avatarData
                                #endif
                                do {
                                    uploadedAvatarUrl = try await ProfileService.uploadAvatar(userId: userId, imageData: jpeg)
                                } catch {
                                    viewModel.errorMessage = "Failed to upload photo: \(error.localizedDescription)"
                                    isSaving = false
                                    return
                                }
                            }
                            await viewModel.updateProfile(
                                firstName: firstName.isEmpty ? nil : firstName,
                                lastName: lastName.isEmpty ? nil : lastName,
                                middleName: middleName,
                                username: username.isEmpty ? nil : username,
                                duprRating: duprConnected ? nil : Double(duprRating),
                                avatarUrl: uploadedAvatarUrl
                            )
                            isSaving = false
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
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
                    duprConnected = user.isDuprConnected
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
