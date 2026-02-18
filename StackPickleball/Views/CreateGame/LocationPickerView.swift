import SwiftUI
import MapKit

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var completer = LocationCompleter()
    @State private var nearbyCourts: [MKMapItem] = []
    @State private var isLoadingNearby = true
    @State private var isResolving = false

    let userLatitude: Double?
    let userLongitude: Double?
    let onSelect: (String, Double, Double) -> Void

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                if isResolving {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if isSearching {
                    // Autocomplete results while typing
                    if completer.results.isEmpty {
                        Text("No results found")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(completer.results, id: \.self) { completion in
                            Button {
                                Task { await selectCompletion(completion) }
                            } label: {
                                completionRow(completion)
                            }
                        }
                    }
                } else {
                    // Nearby pickleball courts
                    Section {
                        if isLoadingNearby {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else if nearbyCourts.isEmpty {
                            Text("No courts found nearby")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(nearbyCourts, id: \.self) { item in
                                Button {
                                    let name = item.name ?? "Unknown"
                                    let coord = item.placemark.coordinate
                                    onSelect(name, coord.latitude, coord.longitude)
                                    dismiss()
                                } label: {
                                    mapItemRow(item)
                                }
                            }
                        }
                    } header: {
                        Text("Nearby Courts")
                    }
                }
            }
            .navigationTitle("Choose Location")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $searchText, prompt: "Search parks, courts, addresses...")
            .onChange(of: searchText) {
                completer.search(query: searchText)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                completer.setRegion(lat: userLatitude, lng: userLongitude)
                await loadNearbyCourts()
            }
        }
    }

    // MARK: - Row Views

    private func completionRow(_ completion: MKLocalSearchCompletion) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(completion.title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)

            if !completion.subtitle.isEmpty {
                Text(completion.subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func mapItemRow(_ item: MKMapItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.pickleball")
                .font(.system(size: 16))
                .foregroundColor(.orange)
                .frame(width: 28)

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
        }
        .padding(.vertical, 4)
    }

    // MARK: - Data Loading

    private func loadNearbyCourts() async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "pickleball"
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: userLatitude ?? 30.2672,
                longitude: userLongitude ?? -97.7431
            ),
            span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
        )

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            nearbyCourts = response.mapItems
        } catch {
            nearbyCourts = []
        }
        isLoadingNearby = false
    }

    private func selectCompletion(_ completion: MKLocalSearchCompletion) async {
        isResolving = true
        let request = MKLocalSearch.Request(completion: completion)
        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            if let item = response.mapItems.first {
                let name = item.name ?? completion.title
                let coord = item.placemark.coordinate
                onSelect(name, coord.latitude, coord.longitude)
                dismiss()
            }
        } catch {
            // Resolve failed — stay on picker
        }
        isResolving = false
    }

    private func formatSubtitle(_ item: MKMapItem) -> String? {
        let placemark = item.placemark
        let parts = [placemark.thoroughfare, placemark.locality, placemark.administrativeArea].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}

// MARK: - Search Completer

@Observable
class LocationCompleter: NSObject, MKLocalSearchCompleterDelegate {
    var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func setRegion(lat: Double?, lng: Double?) {
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: lat ?? 30.2672,
                longitude: lng ?? -97.7431
            ),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
    }

    func search(query: String) {
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Silently handle - results just stay empty
    }
}
