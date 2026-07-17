import Foundation

/// ⚔️ 今週の試練: 週替わりの特殊ルール盛り合わせで難易度「鬼」に勝つ。週1回。
/// 「今日の挑戦」より高難度のガチ勢向けチャレンジ。
enum WeeklyChallenge {

    /// その週のルールセット。ISO週番号をシードに決定的に生成されるため、
    /// 全ユーザーが同じルールで挑戦する。難易度は常に「鬼」、特殊ルールは必ず3つ。
    static func config(for date: Date = .now) -> GameConfig {
        var rng = SplitMix64(state: seed(for: date))

        var config = GameConfig()
        config.gameMode = .vsAI
        config.aiDifficulty = .oni
        config.aiLevel = nil
        config.isWeeklyChallenge = true

        config.isOverflowWrapEnabled = Bool.random(using: &rng)
        config.handCount = Double.random(in: 0..<1, using: &rng) < 0.3 ? 3 : 2

        // 特殊ルール5種からちょうど3つを有効化（決定的シャッフル）
        var specials = [0, 1, 2, 3, 4]
        specials.shuffle(using: &rng)
        for special in specials.prefix(3) {
            switch special {
            case 0:
                config.isSplittingEnabled = true
                config.isDeadHandRevivalEnabled = Bool.random(using: &rng)
            case 1: config.isPoisonEnabled = true
            case 2: config.isBombEnabled = true
            case 3: config.isMirrorEnabled = true
            default: config.isDoubleTapEnabled = true
            }
        }
        return config
    }

    /// メニュー表示用の週ラベル（例: "第29週"）
    static func title(for date: Date = .now) -> String {
        let week = isoWeek(for: date).week
        return String(localized: "第\(week)週")
    }

    /// ISO 8601の週（月曜はじまり）。週の切り替わり判定とシードに使う。
    static func isoWeek(for date: Date) -> (year: Int, week: Int) {
        let calendar = Calendar(identifier: .iso8601)
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return (components.yearForWeekOfYear ?? 0, components.weekOfYear ?? 0)
    }

    private static func seed(for date: Date) -> UInt64 {
        let (year, week) = isoWeek(for: date)
        // 日替わりシード（YYYYMMDD形式）と衝突しない別系列にする
        return UInt64(year * 100 + week) &+ 0x5EED_0002_0000_0000
    }
}
