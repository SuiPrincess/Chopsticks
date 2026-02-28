import SwiftUI

struct GlassButtonStyle: ButtonStyle {
    var color: Color = AppTheme.accent
    var isPrimary: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isPrimary
                                    ? AnyShapeStyle(
                                        LinearGradient(
                                            colors: [color, color.opacity(0.4)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    : AnyShapeStyle(Color.white.opacity(0.15)),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: isPrimary ? color.opacity(0.3) : .clear, radius: 12)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(Anim.buttonPress, value: configuration.isPressed)
    }
}
