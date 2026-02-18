import SwiftUI
import MapKit

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var results: [MKMapItem] = []
    @State private var isSearching = false

    let userLatitude: Double?
    let userLongitude: Double?
    let onSelect: (String, Double, Double) -> Void

    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if results.isEmpty && !searchText.isEmpty {
                    Text("No results found")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(results, id: \.self) { item in
                        Button {
                            let name = item.name ?? "Unknown"
                            let coord = item.placemark.coordinate
                            onSelect(name, coord.latitude, coord.longitude)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name ?? "Unknown")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)

                                if let subtitle = formatSubtitle(item) {
                                    Text(subtitle)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Choose Location")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $searchText, prompt: "Search parks, courts, venues...")
            .onChange(of: searchText) {
                Task { await search() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                // Pre-search for pickleball nearby on open
                searchText = "pickleball"
                await search()
            }
        }
    }

    private func search() async {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            results = []
            return
        }

        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: userLatitude ?? 30.2672,
                longitude: userLongitude ?? -97.7431
            ),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            results = response.mapItems
        } catch {
            results = []
        }
        isSearching = false
    }

    private func formatSubtitle(_ item: MKMapItem) -> String? {
        let placemark = item.placemark
        let parts = [placemark.locality, placemark.administrativeArea].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
