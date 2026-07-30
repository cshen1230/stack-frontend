import SwiftUI

/// Pops up over the planner once you've blocked out a slot. The time, the court and the player
/// count all came from the drag or from defaults — all that's left is the type and the guests.
struct SessionDraftSheet: View {
    @Bindable var viewModel: SessionDraftViewModel
    let readyFriends: [ReadyFriend]
    var onCreated: (CreatedSessionInfo) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var locationManager: LocationManager
    @State private var showingLocationPicker = false
    @State private var searchTask: Task<Void, Never>?

    private var currentUserId: UUID? { appState.currentUser?.id }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    timeHeader
                    typeAndFormat
                    locationRow
                    invitesSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 100)
            }
            .background(Color.stackBackground)
            .safeAreaInset(edge: .bottom) { createBar }
            .navigationTitle("New Session")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(
                    userLatitude: locationManager.latitude,
                    userLongitude: locationManager.longitude
                ) { name, lat, lng in
                    viewModel.locationName = name
                    viewModel.latitude = lat
                    viewModel.longitude = lng
                }
            }
            .task {
                await viewModel.load(currentUserId: currentUserId, readyFriends: readyFriends)
            }
            .errorAlert($viewModel.errorMessage)
        }
        .presentationDetents([.large])
    }

    // MARK: - Time

    private var timeHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(viewModel.rangeLabel)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.stackGreen)
            Text(viewModel.dayLabel)
                .font(.system(size: 15))
                .foregroundColor(.stackSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: - Type & format

    private var typeAndFormat: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Session type", selection: $viewModel.sessionType) {
                ForEach(SessionType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.availableFormats, id: \.self) { format in
                        Button {
                            viewModel.gameFormat = format
                        } label: {
                            Text(format.displayName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(viewModel.gameFormat == format ? .white : .primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(viewModel.gameFormat == format ? Color.stackGreen : Color.stackCardWhite)
                                .cornerRadius(9)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9)
                                        .stroke(viewModel.gameFormat == format ? Color.clear : Color.stackBorder, lineWidth: 1)
                                )
                        }
                    }
                }
            }

            if viewModel.isRoundRobin {
                Stepper("Rounds: \(viewModel.numRounds)", value: $viewModel.numRounds, in: 1...30)
                    .font(.system(size: 15))
            }
        }
        .onChange(of: viewModel.sessionType) {
            // Drill has no meaning in a round robin; fall back to the common case.
            if viewModel.isRoundRobin && viewModel.gameFormat == .drill {
                viewModel.gameFormat = .doubles
            }
        }
    }

    // MARK: - Location

    private var locationRow: some View {
        Button {
            showingLocationPicker = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.stackGreen)

                Text(viewModel.locationName.isEmpty ? "Add a court" : viewModel.locationName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(viewModel.locationName.isEmpty ? .stackSecondaryText : .primary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.stackSecondaryText)
            }
            .padding(14)
            .background(Color.stackCardWhite)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Invites

    private var invitesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !viewModel.freeThen.isEmpty {
                sectionLabel("Free then", accent: true)
                VStack(spacing: 0) {
                    ForEach(viewModel.freeThen) { friend in
                        inviteRow(
                            id: friend.userId,
                            name: friend.displayName,
                            avatarUrl: friend.avatarUrl,
                            detail: "Free \(friend.windowLabel())"
                        )
                    }
                }
                .background(Color.stackCardWhite)
                .cornerRadius(12)
            }

            sectionLabel("Invite anyone", accent: false)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.stackSecondaryText)
                TextField("Search players by name", text: $viewModel.searchQuery)
                    .font(.system(size: 15))
                    .autocorrectionDisabled()
                if viewModel.isSearching {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(12)
            .background(Color.stackCardWhite)
            .cornerRadius(12)
            .onChange(of: viewModel.searchQuery) {
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    await viewModel.search(currentUserId: currentUserId)
                }
            }

            let rows = combinedRows
            if rows.isEmpty {
                Text(viewModel.searchQuery.isEmpty
                     ? "Add friends to invite them in one tap."
                     : "No players found.")
                    .font(.system(size: 14))
                    .foregroundColor(.stackSecondaryText)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(rows, id: \.id) { row in
                        inviteRow(id: row.id, name: row.name, avatarUrl: row.avatarUrl, detail: row.detail)
                    }
                }
                .background(Color.stackCardWhite)
                .cornerRadius(12)
            }
        }
    }

    /// Search results when searching, your friends otherwise.
    private var combinedRows: [InviteCandidate] {
        if !viewModel.searchResults.isEmpty {
            return viewModel.searchResults.map {
                InviteCandidate(id: $0.id, name: $0.displayName, avatarUrl: $0.avatarUrl, detail: "@\($0.username)")
            }
        }
        if viewModel.searchQuery.isEmpty {
            return viewModel.otherFriends.map {
                InviteCandidate(id: $0.friendUserId, name: $0.displayName, avatarUrl: $0.avatarUrl, detail: "@\($0.username)")
            }
        }
        return []
    }

    private struct InviteCandidate {
        let id: UUID
        let name: String
        let avatarUrl: String?
        let detail: String
    }

    private func sectionLabel(_ text: String, accent: Bool) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(accent ? .stackGreen : .stackSecondaryText)
            .textCase(.uppercase)
    }

    private func inviteRow(id: UUID, name: String, avatarUrl: String?, detail: String) -> some View {
        Button {
            viewModel.toggleInvite(id: id, name: name)
        } label: {
            HStack(spacing: 12) {
                AvatarCircle(urlString: avatarUrl, name: name, size: 36)

                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundColor(.stackSecondaryText)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: viewModel.isInvited(id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21))
                    .foregroundColor(viewModel.isInvited(id) ? .stackGreen : .stackBorder)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Create

    private var createBar: some View {
        Button {
            Task {
                if let info = await viewModel.create() {
                    onCreated(info)
                    dismiss()
                }
            }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isCreating {
                    ProgressView().tint(.white)
                }
                Text(createTitle)
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.stackGreen)
            .cornerRadius(14)
        }
        .disabled(viewModel.isCreating)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private var createTitle: String {
        let count = viewModel.invitedIds.count
        return count == 0 ? "Create Session" : "Create & Invite \(count)"
    }
}

/// Avatar with an initial fallback — the same treatment used across the invite lists.
struct AvatarCircle: View {
    let urlString: String?
    let name: String
    var size: CGFloat = 36

    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    fallback
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var fallback: some View {
        Circle()
            .fill(Color.stackGreen)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundColor(.white)
            )
    }
}
