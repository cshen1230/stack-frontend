import SwiftUI

struct SessionTypePickerView: View {
    var onCreated: ((CreatedSessionInfo) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: SessionType?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Choose Session Type")
                    .font(.system(size: 24, weight: .bold))
                    .padding(.top, 24)

                // Casual
                Button {
                    selectedType = .casual
                } label: {
                    SessionTypeCard(
                        icon: "figure.pickleball",
                        title: "Casual",
                        description: "Standard game session. Players join and play freely with no structured format."
                    )
                }
                .buttonStyle(.plain)

                // Round Robin
                Button {
                    selectedType = .roundRobin
                } label: {
                    SessionTypeCard(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Round Robin",
                        description: "Rotating partners each round with score tracking and a leaderboard. Supports singles and doubles."
                    )
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 16)
            .background(Color.stackBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(item: $selectedType) { type in
                CreateGameView(sessionType: type, onCreated: onCreated)
            }
        }
    }
}

// MARK: - Card

private struct SessionTypeCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.stackGreen)
                .frame(width: 52, height: 52)
                .background(Color.stackBadgeBg)
                .cornerRadius(14)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color.stackCardWhite)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black, lineWidth: 1)
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.stackGreen.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.black, lineWidth: 1)
                )
                .offset(x: 3, y: 4)
        )
    }
}
