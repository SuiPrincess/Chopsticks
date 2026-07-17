import SwiftUI

/// アプリ全体のカラーパレット。実体はThemeStoreの選択テーマで、
/// テーマを切り替えると全Viewに反映される。
enum AppTheme {
    // Player colors
    static var player1Color: Color { ThemeStore.shared.current.player1 }
    static var player2Color: Color { ThemeStore.shared.current.player2 }

    // Accent
    static var accent: Color { ThemeStore.shared.current.accent }
    static var accentSecondary: Color { ThemeStore.shared.current.accentSecondary }

    // Background
    static var bgDark: Color { ThemeStore.shared.current.bgDark }
    static var bgMid: Color { ThemeStore.shared.current.bgMid }
    static var bgDeep: Color { ThemeStore.shared.current.bgDeep }

    // Glass
    static let glassBorder = Color.white.opacity(0.15)

    // Gradients
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accentSecondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static let goldGradient = LinearGradient(
        colors: [.yellow, .orange],
        startPoint: .top,
        endPoint: .bottom
    )
}
