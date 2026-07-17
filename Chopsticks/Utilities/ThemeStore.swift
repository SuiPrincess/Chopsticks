import SwiftUI
import Observation

/// テーマの解放条件
enum ThemeUnlock: Equatable {
    case free
    case premium
    /// 「今日の挑戦」を通算n回クリアで解放（プレミアム不要の報酬テーマ）
    case dailyChallengeClears(Int)
}

/// カラーテーマ。プレミアム購入または報酬条件で解放される。
struct Theme: Identifiable, Equatable {
    let id: String
    let name: String
    let unlock: ThemeUnlock

    let player1: Color
    let player2: Color
    let accent: Color
    let accentSecondary: Color
    let bgDark: Color
    let bgMid: Color
    let bgDeep: Color

    var isPremium: Bool { unlock == .premium }

    func isUnlocked(isPremiumPurchased: Bool, challengeClears: Int) -> Bool {
        switch unlock {
        case .free:
            return true
        case .premium:
            return isPremiumPurchased
        case .dailyChallengeClears(let required):
            return challengeClears >= required
        }
    }
}

extension Theme {
    /// デフォルト（無料）: ネオンシアン×ピンク
    static let neon = Theme(
        id: "neon",
        name: String(localized: "ネオン"),
        unlock: .free,
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
        unlock: .premium,
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
        unlock: .premium,
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
        unlock: .premium,
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
        unlock: .premium,
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
        unlock: .premium,
        player1: Color(red: 0.25, green: 0.85, blue: 0.85),
        player2: Color(red: 0.4, green: 0.55, blue: 1.0),
        accent: Color(red: 0.3, green: 0.85, blue: 0.9),
        accentSecondary: Color(red: 0.2, green: 0.45, blue: 0.95),
        bgDark: Color(red: 0.01, green: 0.03, blue: 0.08),
        bgMid: Color(red: 0.02, green: 0.07, blue: 0.14),
        bgDeep: Color(red: 0.03, green: 0.05, blue: 0.16)
    )

    /// 🎁 報酬テーマ: 「今日の挑戦」通算7回クリアで解放（課金不要）
    static let midnight = Theme(
        id: "midnight",
        name: String(localized: "ミッドナイト"),
        unlock: .dailyChallengeClears(7),
        player1: Color(red: 0.75, green: 0.85, blue: 1.0),
        player2: Color(red: 0.85, green: 0.75, blue: 1.0),
        accent: Color(red: 0.7, green: 0.8, blue: 1.0),
        accentSecondary: Color(red: 0.55, green: 0.5, blue: 0.95),
        bgDark: Color(red: 0.00, green: 0.00, blue: 0.02),
        bgMid: Color(red: 0.03, green: 0.03, blue: 0.08),
        bgDeep: Color(red: 0.05, green: 0.02, blue: 0.10)
    )

    static let all: [Theme] = [.neon, .sunset, .matrix, .sakura, .luxeGold, .deepSea, .midnight]
}

/// 選択中のテーマ。AppThemeのアクセサ経由で全Viewが参照する。
/// （UIスレッドからのみ変更される前提の軽量ストア）
@Observable
final class ThemeStore {
    static let shared = ThemeStore(defaults: .standard)

    private static let key = "theme.selected"

    private let defaults: UserDefaults

    var selectedThemeID: String {
        didSet { defaults.set(selectedThemeID, forKey: Self.key) }
    }

    var current: Theme {
        Theme.all.first { $0.id == selectedThemeID } ?? .neon
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        selectedThemeID = defaults.string(forKey: Self.key) ?? Theme.neon.id
    }

    /// 解放済みのテーマのみ選択できる
    func select(_ theme: Theme, isPremiumPurchased: Bool, challengeClears: Int) {
        guard theme.isUnlocked(
            isPremiumPurchased: isPremiumPurchased,
            challengeClears: challengeClears
        ) else { return }
        selectedThemeID = theme.id
    }
}
