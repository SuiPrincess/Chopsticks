import SwiftUI

struct BackgroundGradientView: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.bgDark,
                    AppTheme.bgDeep,
                    AppTheme.bgMid,
                    AppTheme.bgDeep,
                    AppTheme.bgDark
                ],
                startPoint: animate ? .topLeading : .bottomLeading,
                endPoint: animate ? .bottomTrailing : .topTrailing
            )

            // Subtle radial accent glow
            RadialGradient(
                colors: [
                    AppTheme.accent.opacity(0.06),
                    .clear
                ],
                center: animate ? .init(x: 0.6, y: 0.3) : .init(x: 0.4, y: 0.7),
                startRadius: 50,
                endRadius: 400
            )
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}
