import SwiftUI
import MapKit

struct SessionMapView: View {
    let games: [Game]
    let joinedGameIds: Set<UUID>
    let currentUserId: UUID?
    let onJoin: (Game) -> Void
    let onView: (Game) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedGame: Game?
    @State private var position: MapCameraPosition
    @State private var pickleballCourts: [MKMapItem] = []

    private let userLatitude: Double
    private let userLongitude: Double

    init(
        games: [Game],
        joinedGameIds: Set<UUID>,
        currentUserId: UUID?,
        userLatitude: Double?,
        userLongitude: Double?,
        onJoin: @escaping (Game) -> Void,
        onView: @escaping (Game) -> Void
    ) {
        self.games = games
        self.joinedGameIds = joinedGameIds
        self.currentUserId = currentUserId
        self.onJoin = onJoin
        self.onView = onView
        self.userLatitude = userLatitude ?? 30.2672
        self.userLongitude = userLongitude ?? -97.7431

        let center = CLLocationCoordinate2D(
            latitude: userLatitude ?? 30.2672,
            longitude: userLongitude ?? -97.7431
        )
        self._position = State(initialValue: .region(
            MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
            )
        ))
    }

    private var gamesWithCoordinates: [Game] {
        games.filter { $0.coordinate != nil }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $position) {
                // Game session pins
                ForEach(gamesWithCoordinates) { game in
                    Annotation("", coordinate: game.coordinate!) {
                        mapPin(for: game)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedGame = selectedGame?.id == game.id ? nil : game
                                }
                            }
                    }
                }

                // Nearby pickleball courts/parks
                ForEach(pickleballCourts, id: \.self) { court in
                    Marker(
                        court.name ?? "Court",
                        systemImage: "figure.pickleball",
                        coordinate: court.placemark.coordinate
                    )
                    .tint(.orange)
                }
            }
            .mapControls { }
            .ignoresSafeArea(edges: .top)
            .task {
                await searchPickleballCourts()
            }

            // Floating top-right buttons
            VStack {
                HStack {
                    Spacer()

                    HStack(spacing: 10) {
                        Button {
                            withAnimation {
                                position = .region(MKCoordinateRegion(
                                    center: CLLocationCoordinate2D(latitude: userLatitude, longitude: userLongitude),
                                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                ))
                            }
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.8))
                                .clipShape(Circle())
                        }

                        Button {
                            dismiss()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("List")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.8))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.trailing, 16)
                }
                Spacer()
            }
            .padding(.top, 10)

            // Bottom card when a pin is selected
            if let game = selectedGame {
                selectedGameCard(game: game)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Map Pin

    private func mapPin(for game: Game) -> some View {
        let isSelected = selectedGame?.id == game.id
        return Text(game.sessionName ?? game.gameFormat.displayName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(isSelected ? .white : .primary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? game.gameFormat.accentColor : Color.stackCardWhite)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.black, lineWidth: 1)
            )
            .scaleEffect(isSelected ? 1.1 : 1.0)
    }

    // MARK: - Selected Game Card

    // MARK: - Pickleball Court Search

    private func searchPickleballCourts() async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "pickleball"
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: games.first?.latitude ?? 30.2672,
                longitude: games.first?.longitude ?? -97.7431
            ),
            span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
        )

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            pickleballCourts = response.mapItems
        } catch {
            // Search failed silently — courts just won't show
        }
    }

    // MARK: - Selected Game Card

    private func selectedGameCard(game: Game) -> some View {
        let isHost = game.creatorId == currentUserId
        let isJoined = joinedGameIds.contains(game.id)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if isHost {
                        Text("Host")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .cornerRadius(4)
                    }

                    Text(game.sessionName ?? game.creatorDisplayName)
                        .font(.system(size: 18, weight: .bold))
                        .lineLimit(1)

                    HStack(spacing: 12) {
                        Text("\(game.spotsFilled)/\(game.spotsAvailable) spots")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)

                        if let min = game.skillLevelMin {
                            Text("DUPR \(String(format: "%.1f", min))+")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        Text(game.gameFormat.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    if let location = game.locationName {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.system(size: 11))
                            Text(location)
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Action buttons
                VStack(spacing: 8) {
                    Button { onView(game) } label: {
                        Text("View")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.stackGreen)
                            .frame(width: 72)
                            .padding(.vertical, 8)
                            .background(Color.stackGreen.opacity(0.15))
                            .cornerRadius(8)
                    }

                    if !isJoined {
                        if game.spotsRemaining > 0 {
                            Button { onJoin(game) } label: {
                                Text("Join")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 72)
                                    .padding(.vertical, 8)
                                    .background(Color.stackGreen)
                                    .cornerRadius(8)
                            }
                        } else {
                            Text("Full")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.stackCardWhite)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }
}
