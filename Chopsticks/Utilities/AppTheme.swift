import SwiftUI

enum AppTheme {
    // Player colors
    static let player1Color = Color(red: 0.3, green: 0.75, blue: 1.0)
    static let player2Color = Color(red: 1.0, green: 0.4, blue: 0.65)

    // Accent
    static let accent = Color(red: 0.3, green: 0.75, blue: 1.0)
    static let accentSecondary = Color(red: 0.6, green: 0.4, blue: 1.0)

    // Background
    static let bgDark = Color(red: 0.02, green: 0.02, blue: 0.08)
    static let bgMid = Color(red: 0.05, green: 0.05, blue: 0.15)
    static let bgDeep = Color(red: 0.08, green: 0.02, blue: 0.12)

    // Glass
    static let glassBorder = Color.white.opacity(0.15)

    // Gradients
    static let accentGradient = LinearGradient(
        colors: [accent, accentSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let goldGradient = LinearGradient(
        colors: [.yellow, .orange],
        startPoint: .top,
        endPoint: .bottom
    )
}
