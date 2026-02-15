import SwiftUI

struct PlayerSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [User] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            List(results) { player in
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(player.displayName)
                            .font(.system(size: 16, weight: .semibold))
                        Text("@\(player.username)")
                            .font(.system(size: 14))
                            .foregroundColor(.stackSecondaryText)
                    }

                    Spacer()

                    if let dupr = player.duprRating {
                        HStack(spacing: 4) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                            Text(String(format: "%.1f", dupr))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.stackDUPRBadge)
                        .cornerRadius(12)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .listStyle(.plain)
            .searchable(text: $query, prompt: "Search by name or username")
            .onChange(of: query) { _, newValue in
                guard newValue.count >= 2 else {
                    results = []
                    return
                }
                Task {
                    isLoading = true
                    do {
                        results = try await PlayerService.searchPlayers(query: newValue)
                    } catch {
                        results = []
                    }
                    isLoading = false
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
            .navigationTitle("Find Players")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    PlayerSearchView()
}
