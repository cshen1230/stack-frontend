import SwiftUI

struct FilterBarView: View {
    @Binding var distance: Double
    let onApply: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Distance filter
                FilterChip(
                    icon: "mappin.circle",
                    text: "\(Int(distance)) mi",
                    isActive: true
                ) {
                    // Cycle through distance options
                    let options: [Double] = [5, 10, 20, 50]
                    if let idx = options.firstIndex(of: distance) {
                        distance = options[(idx + 1) % options.count]
                    } else {
                        distance = 20
                    }
                    onApply()
                }

                // Game format filters
                ForEach(GameFormat.allCases, id: \.self) { format in
                    FilterChip(
                        icon: "sportscourt",
                        text: format.displayName,
                        isActive: false
                    ) {
                        // Filter action placeholder
                    }
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
        distance: .constant(20.0),
        onApply: {}
    )
    .padding(16)
}
