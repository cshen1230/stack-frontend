import SwiftUI

struct FilterBarView: View {
    @Binding var duprMin: Double
    @Binding var duprMax: Double
    @Binding var date: Date
    @Binding var distance: Double
    let onApply: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // DUPR filter (active)
                FilterChip(
                    icon: "trophy",
                    text: "DUPR \(String(format: "%.1f", duprMin))-\(String(format: "%.1f", duprMax))",
                    isActive: true
                ) {
                    // TODO: Show DUPR picker
                }

                // Date filter (inactive)
                FilterChip(
                    icon: "calendar",
                    text: "Today",
                    isActive: false
                ) {
                    // TODO: Show date picker
                }

                // Distance filter (inactive)
                FilterChip(
                    icon: "mappin.circle",
                    text: "\(Int(distance)) mi",
                    isActive: false
                ) {
                    // TODO: Show distance picker
                }
            }
        }
    }
}

struct FilterChip: View {
    let icon: String
    let text: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(text)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isActive ? .white : .black)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isActive ? Color.stackFilterActive : Color.stackFilterInactive)
            .cornerRadius(20)
        }
    }
}

#Preview {
    FilterBarView(
        duprMin: .constant(3.0),
        duprMax: .constant(4.5),
        date: .constant(Date()),
        distance: .constant(5.0),
        onApply: {}
    )
    .padding(16)
}
