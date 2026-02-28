import SwiftUI

struct Particle: Identifiable {
    let id = UUID()
    var color: Color
    var size: CGFloat
    var offset: CGSize
    var opacity: Double
}

struct ParticleExplosionView: View {
    let isActive: Bool
    let color: Color

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
        .onChange(of: isActive) { _, active in
            if active { explode() }
        }
    }

    private func explode() {
        let colors: [Color] = [color, .white, .orange, .yellow]
        particles = (0..<20).map { _ in
            Particle(
                color: colors.randomElement()!,
                size: CGFloat.random(in: 3...8),
                offset: .zero,
                opacity: 1.0
            )
        }

        withAnimation(.easeOut(duration: 0.8)) {
            particles = particles.map { p in
                var new = p
                new.offset = CGSize(
                    width: CGFloat.random(in: -90...90),
                    height: CGFloat.random(in: -90...90)
                )
                new.opacity = 0
                new.size = p.size * 0.2
                return new
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            particles = []
        }
    }
}
