import SwiftUI

struct GlowPulse: ViewModifier {
    let isActive: Bool
    let color: Color

    @State private var glow: CGFloat = 0.3

    func body(content: Content) -> some View {
        content
            .shadow(color: isActive ? color.opacity(glow) : .clear, radius: 12)
            .shadow(color: isActive ? color.opacity(glow * 0.5) : .clear, radius: 24)
            .onAppear { startPulse() }
            .onChange(of: isActive) { _, _ in startPulse() }
    }

    private func startPulse() {
        guard isActive else {
            withAnimation(.easeOut(duration: 0.3)) { glow = 0 }
            return
        }
        withAnimation(Anim.glowPulse) { glow = 0.9 }
    }
}

extension View {
    func glowPulse(isActive: Bool, color: Color) -> some View {
        modifier(GlowPulse(isActive: isActive, color: color))
    }
}

/// animatableDataが1進むごとに左右3往復する画面シェイク
struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = 7 * sin(animatableData * .pi * 6)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}
