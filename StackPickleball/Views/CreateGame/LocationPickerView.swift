import SwiftUI
import MapKit

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var completer = LocationCompleter()
    @State private var isResolving = false

    let userLatitude: Double?
    let userLongitude: Double?
    let onSelect: (String, Double, Double) -> Void

    var body: some View {
        NavigationStack {
            List {
                if isResolving {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if completer.results.isEmpty && !searchText.isEmpty {
                    Text("No results found")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(completer.results, id: \.self) { completion in
                        Button {
                            Task { await selectCompletion(completion) }
                        } label: {
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
            .onAppear {
                completer.setRegion(lat: userLatitude, lng: userLongitude)
                completer.search(query: "pickleball")
                searchText = "pickleball"
            }
        }
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
            // Fall back to just the title with no coordinates
        }
        isResolving = false
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
