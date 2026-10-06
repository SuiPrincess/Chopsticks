import SwiftUI

struct Particle: Identifiable {
    let id = UUID()
    var color: Color
    var size: CGFloat
    var offset: CGSize
    var opacity: Double
}

/// 手が死んだときの破片エフェクト
struct ParticleExplosionView: View {
    let isActive: Bool
    let color: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var particles: [Particle] = []

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                Circle()
                    .fill(p.color)
                    .frame(width: p.size, height: p.size)
                    .blur(radius: 1)
                    .offset(p.offset)
                    .opacity(p.opacity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: isActive) {
            guard isActive, !reduceMotion, !AppSettings.shared.reducesEffects else { return }
            let colors: [Color] = [color, .white, .orange, .yellow]
            particles = (0..<20).map { _ in
                Particle(
                    color: colors.randomElement() ?? color,
                    size: CGFloat.random(in: 3...8),
                    offset: .zero,
                    opacity: 1.0
                )
            }
            // 初期配置が描画されてから広げる
            try? await Task.sleep(for: .milliseconds(30))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.8)) {
                particles = particles.map { p in
                    var moved = p
                    moved.offset = CGSize(width: CGFloat.random(in: -90...90), height: CGFloat.random(in: -90...90))
                    moved.opacity = 0
                    moved.size = p.size * 0.2
                    return moved
                }
            }
            try? await Task.sleep(for: .milliseconds(900))
            particles = []
        }
    }
}
