import SwiftUI

/// Pops up over the planner once you've blocked out a slot. The time, the court and the player
/// count all came from the drag or from defaults — all that's left is the type and the guests.
struct SessionDraftSheet: View {
    @Bindable var viewModel: SessionDraftViewModel
    let slots: [FriendAvailability]
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
                .padding(.horizontal, AppConstants.screenPadding)
                .padding(.top, 4)
                .padding(.bottom, 100)
            }
            .background(Color.stackBackground)
            .safeAreaInset(edge: .bottom) { createBar }
            .navigationTitle("New game")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // A symbol, not the word "Cancel". This slot renders inside a circular
                    // container, which a text label can only lose a fight with — it came out as
                    // a white circle reading "Ca…". A close glyph is what the shape is for.
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .accessibilityLabel("Cancel")
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
                await viewModel.load(currentUserId: currentUserId, slots: slots)
            }
            .errorAlert($viewModel.errorMessage)
        }
        // No explicit detents: a sheet without them is already full height, and pinning one
        // constrains the zoom's interactive dismiss — the drag-down that should shrink the sheet
        // back into the block it came from.
    }

    // MARK: - Time

    private var timeHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(viewModel.rangeLabel)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.stackGreen)
            Text(viewModel.dayLabel)
                .font(AppFonts.body())
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
                                .background(viewModel.gameFormat == format ? Color.stackGreen : Color(.secondarySystemBackground))
                                .cornerRadius(9)
                        }
                    }
                }
            }

            if viewModel.isRoundRobin {
                Stepper("Rounds: \(viewModel.numRounds)", value: $viewModel.numRounds, in: 1...30)
                    .font(AppFonts.body())
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
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Invites

    private var invitesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !viewModel.freeThen.isEmpty {
                sectionLabel("Usually free then", accent: true)
                VStack(spacing: 0) {
                    ForEach(viewModel.freeThen) { friend in
                        inviteRow(
                            id: friend.userId,
                            name: friend.displayName,
                            avatarUrl: friend.avatarUrl,
                            detail: "Usually plays \(friend.timeRangeLabel)"
                        )
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }

            sectionLabel("Invite anyone", accent: false)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.stackSecondaryText)
                TextField("Search players by name", text: $viewModel.searchQuery)
                    .font(AppFonts.body())
                    .autocorrectionDisabled()
                if viewModel.isSearching {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
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
                    .font(AppFonts.callout())
                    .foregroundColor(.stackSecondaryText)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(rows, id: \.id) { row in
                        inviteRow(id: row.id, name: row.name, avatarUrl: row.avatarUrl, detail: row.detail)
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }

            // ── Invite via text ────────────────────────
            sectionLabel("Invite via text", accent: false)

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    TextField("Name", text: $viewModel.currentSMSEntry.name)
                        .font(AppFonts.body())
                        .textContentType(.name)
                        .autocorrectionDisabled()
                        .padding(10)
                        .background(Color(.systemBackground))
                        .cornerRadius(10)

                    TextField("Phone", text: $viewModel.currentSMSEntry.phoneNumber)
                        .font(AppFonts.body())
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                        .padding(10)
                        .background(Color(.systemBackground))
                        .cornerRadius(10)

                    Button {
                        viewModel.addSMSInvite()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(viewModel.currentSMSEntry.isValid ? .stackGreen : .gray.opacity(0.4))
                    }
                    .disabled(!viewModel.currentSMSEntry.isValid)
                }

                if !viewModel.smsInvites.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(viewModel.smsInvites) { entry in
                            HStack(spacing: 12) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.stackGreen)
                                    .frame(width: 36, height: 36)
                                    .background(Color.stackGreen.opacity(0.15))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(entry.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    Text(entry.phoneNumber)
                                        .font(AppFonts.caption())
                                        .foregroundColor(.stackSecondaryText)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Button {
                                    if let idx = viewModel.smsInvites.firstIndex(where: { $0.id == entry.id }) {
                                        viewModel.removeSMSInvite(at: IndexSet(integer: idx))
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
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
                        .font(AppFonts.caption())
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
            }
            .primaryButton()
        }
        .disabled(viewModel.isCreating)
        .padding(.horizontal, AppConstants.screenPadding)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private var createTitle: String {
        let count = viewModel.invitedIds.count + viewModel.smsInvites.count
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
