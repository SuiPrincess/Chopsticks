import SwiftUI
import Observation

/// カラーテーマ。プレミアム購入で全テーマが解放される。
struct Theme: Identifiable, Equatable {
    let id: String
    let name: String
    let isPremium: Bool

    let player1: Color
    let player2: Color
    let accent: Color
    let accentSecondary: Color
    let bgDark: Color
    let bgMid: Color
    let bgDeep: Color
}

extension Theme {
    /// デフォルト（無料）: ネオンシアン×ピンク
    static let neon = Theme(
        id: "neon",
        name: String(localized: "ネオン"),
        isPremium: false,
        player1: Color(red: 0.3, green: 0.75, blue: 1.0),
        player2: Color(red: 1.0, green: 0.4, blue: 0.65),
        accent: Color(red: 0.3, green: 0.75, blue: 1.0),
        accentSecondary: Color(red: 0.6, green: 0.4, blue: 1.0),
        bgDark: Color(red: 0.02, green: 0.02, blue: 0.08),
        bgMid: Color(red: 0.05, green: 0.05, blue: 0.15),
        bgDeep: Color(red: 0.08, green: 0.02, blue: 0.12)
    )

    static let sunset = Theme(
        id: "sunset",
        name: String(localized: "サンセット"),
        isPremium: true,
        player1: Color(red: 1.0, green: 0.6, blue: 0.2),
        player2: Color(red: 0.85, green: 0.3, blue: 0.85),
        accent: Color(red: 1.0, green: 0.55, blue: 0.25),
        accentSecondary: Color(red: 0.95, green: 0.3, blue: 0.5),
        bgDark: Color(red: 0.07, green: 0.02, blue: 0.05),
        bgMid: Color(red: 0.13, green: 0.05, blue: 0.09),
        bgDeep: Color(red: 0.10, green: 0.03, blue: 0.12)
    )

    static let matrix = Theme(
        id: "matrix",
        name: String(localized: "マトリックス"),
        isPremium: true,
        player1: Color(red: 0.25, green: 0.95, blue: 0.45),
        player2: Color(red: 0.85, green: 1.0, blue: 0.3),
        accent: Color(red: 0.3, green: 0.95, blue: 0.5),
        accentSecondary: Color(red: 0.1, green: 0.7, blue: 0.5),
        bgDark: Color(red: 0.01, green: 0.05, blue: 0.02),
        bgMid: Color(red: 0.02, green: 0.10, blue: 0.05),
        bgDeep: Color(red: 0.01, green: 0.08, blue: 0.06)
    )

    static let sakura = Theme(
        id: "sakura",
        name: String(localized: "サクラ"),
        isPremium: true,
        player1: Color(red: 1.0, green: 0.65, blue: 0.8),
        player2: Color(red: 0.75, green: 0.55, blue: 1.0),
        accent: Color(red: 1.0, green: 0.6, blue: 0.75),
        accentSecondary: Color(red: 0.9, green: 0.75, blue: 0.95),
        bgDark: Color(red: 0.08, green: 0.03, blue: 0.07),
        bgMid: Color(red: 0.14, green: 0.06, blue: 0.12),
        bgDeep: Color(red: 0.11, green: 0.04, blue: 0.13)
    )

    static let luxeGold = Theme(
        id: "luxeGold",
        name: String(localized: "ゴールド"),
        isPremium: true,
        player1: Color(red: 1.0, green: 0.83, blue: 0.35),
        player2: Color(red: 0.9, green: 0.92, blue: 0.98),
        accent: Color(red: 1.0, green: 0.8, blue: 0.3),
        accentSecondary: Color(red: 0.85, green: 0.65, blue: 0.25),
        bgDark: Color(red: 0.05, green: 0.04, blue: 0.02),
        bgMid: Color(red: 0.10, green: 0.08, blue: 0.04),
        bgDeep: Color(red: 0.08, green: 0.06, blue: 0.05)
    )

    static let deepSea = Theme(
        id: "deepSea",
        name: String(localized: "ディープシー"),
        isPremium: true,
        player1: Color(red: 0.25, green: 0.85, blue: 0.85),
        player2: Color(red: 0.4, green: 0.55, blue: 1.0),
        accent: Color(red: 0.3, green: 0.85, blue: 0.9),
        accentSecondary: Color(red: 0.2, green: 0.45, blue: 0.95),
        bgDark: Color(red: 0.01, green: 0.03, blue: 0.08),
        bgMid: Color(red: 0.02, green: 0.07, blue: 0.14),
        bgDeep: Color(red: 0.03, green: 0.05, blue: 0.16)
    )

    static let all: [Theme] = [.neon, .sunset, .matrix, .sakura, .luxeGold, .deepSea]
}

/// 選択中のテーマ。AppThemeのアクセサ経由で全Viewが参照する。
/// （UIスレッドからのみ変更される前提の軽量ストア）
@Observable
final class ThemeStore {
    static let shared = ThemeStore()

    private static let key = "theme.selected"

    var selectedThemeID: String {
        didSet { UserDefaults.standard.set(selectedThemeID, forKey: Self.key) }
    }

    var current: Theme {
        Theme.all.first { $0.id == selectedThemeID } ?? .neon
    }

    private init() {
        selectedThemeID = UserDefaults.standard.string(forKey: Self.key) ?? Theme.neon.id
    }

    /// プレミアムでないユーザーが選べるのは無料テーマのみ
    func select(_ theme: Theme, isPremiumUnlocked: Bool) {
        guard !theme.isPremium || isPremiumUnlocked else { return }
        selectedThemeID = theme.id
    }
}
