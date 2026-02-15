import SwiftUI
import PhotosUI

struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationManager: LocationManager
    @State private var viewModel = CreatePostViewModel()
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        if viewModel.selectedImageData != nil {
                            Label("Photo Selected", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.stackGreen)
                        } else {
                            Label("Choose Photo", systemImage: "photo.on.rectangle")
                        }
                    }
                    .onChange(of: selectedItem) { _, newValue in
                        Task {
                            if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                viewModel.selectedImageData = data
                            }
                        }
                    }
                }

                Section("Caption") {
                    TextField("What happened on the court?", text: $viewModel.caption, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("New Post")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        Task {
                            await viewModel.createPost(
                                lat: locationManager.latitude,
                                lng: locationManager.longitude
                            )
                            if viewModel.showingSuccess {
                                dismiss()
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.selectedImageData == nil || viewModel.isLoading)
                }
            }
        }
    }
}

#Preview {
    CreatePostView()
        .environmentObject(LocationManager.shared)
}
