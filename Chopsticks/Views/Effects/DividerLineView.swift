import SwiftUI

struct DividerLineView: View {
    let isPlayer1Turn: Bool

    var body: some View {
        ZStack {
            // Glow line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, accentColor, accentColor, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1.5)
                .shadow(color: accentColor.opacity(0.6), radius: 8)
                .shadow(color: accentColor.opacity(0.3), radius: 20)

            // Turn indicator
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(accentColor.opacity(0.5), lineWidth: 1)
                    )

                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accentColor)
                    .rotationEffect(.degrees(isPlayer1Turn ? 0 : 180))
            }
            .shadow(color: accentColor.opacity(0.5), radius: 8)
        }
        .frame(height: 44)
        .animation(Anim.turnSwitch, value: isPlayer1Turn)
    }

    private var accentColor: Color {
        isPlayer1Turn ? AppTheme.player1Color : AppTheme.player2Color
    }
}
