import SwiftUI

struct CreatedSessionToast: View {
    let info: CreatedSessionInfo
    let onDismiss: () -> Void

    @State private var isVisible = false
    @State private var checkScale: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 14) {
                // Checkmark circle
                ZStack {
                    Circle()
                        .fill(Color.stackGreen)
                        .frame(width: 48, height: 48)

                    Image(systemName: "checkmark")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(checkScale)
                }

                // Title
                Text("Session Created!")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)

                // Session details
                VStack(spacing: 4) {
                    Text(info.sessionName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Label(info.gameFormat.displayName, systemImage: "sportscourt")
                            .font(.system(size: 13))
                            .foregroundColor(.stackSecondaryText)

                        Text("·")
                            .foregroundColor(.stackSecondaryText)

                        Text("\(info.spotsAvailable) spots")
                            .font(.system(size: 13))
                            .foregroundColor(.stackSecondaryText)
                    }

                    if let location = info.locationName {
                        Label(location, systemImage: "mappin")
                            .font(.system(size: 13))
                            .foregroundColor(.stackSecondaryText)
                            .lineLimit(1)
                    }

                    Text(info.sessionType.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.stackGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.stackBadgeBg)
                        .cornerRadius(6)
                        .padding(.top, 2)
                }

                // Hint
                Text("Check Sessions tab to manage your game")
                    .font(.system(size: 12))
                    .foregroundColor(.stackTimestamp)
                    .padding(.top, 2)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity)
            .background(Color.stackCardWhite)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.stackGreen.opacity(0.3), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.12), radius: 20, y: -4)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .offset(y: isVisible ? 0 : 300)
            .opacity(isVisible ? 1 : 0)
        }
        .background(
            Color.black
                .opacity(isVisible ? 0.2 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
        )
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                isVisible = true
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.2)) {
                checkScale = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                dismiss()
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.25)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDismiss()
        }
    }
}
