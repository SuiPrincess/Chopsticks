import Foundation

/// ⚔️ 今週の試練: 週替わりの特殊ルール盛り合わせで難易度「鬼」に勝つ。週1回。
/// 「今日の挑戦」より高難度のガチ勢向けチャレンジ。
enum WeeklyChallenge {

    /// 週替わりで採用するルール構成。厳密ソルバーで
    /// 「先手（人間）に必勝戦略が存在し、最適応答でも9手以上かかる」ことを
    /// 確認済みの構成だけを載せている。後手必勝の構成は鬼AI相手に
    /// 「絶対に勝てない週」になり、数手で終わる構成は自明なチーズになるため除外。
    /// 毒はパリティ退化、ミラーは全構成が不成立で全面除外。
    /// 分析はdocs/ai-notes.md参照。
    private struct Trial {
        var wrap: Bool
        var handCount: Int
        var splitting = false
        var revival = false
        var bomb = false
        var doubleTap = false
    }

    private static let trials: [Trial] = [
        Trial(wrap: true, handCount: 3, splitting: true, revival: true, bomb: true, doubleTap: true),
        Trial(wrap: false, handCount: 3, splitting: true, revival: true, bomb: true, doubleTap: true),
        Trial(wrap: true, handCount: 2, splitting: true, revival: true, bomb: true),
        Trial(wrap: false, handCount: 2, splitting: true, revival: true, bomb: true),
        Trial(wrap: true, handCount: 3, splitting: true, doubleTap: true),
        Trial(wrap: true, handCount: 3, splitting: true, revival: true, doubleTap: true),
        Trial(wrap: false, handCount: 3, splitting: true, doubleTap: true),
        Trial(wrap: false, handCount: 3, splitting: true, revival: true, doubleTap: true),
        Trial(wrap: true, handCount: 2, doubleTap: true),
        Trial(wrap: false, handCount: 3, doubleTap: true),
        Trial(wrap: true, handCount: 3, splitting: true, revival: true),
        Trial(wrap: false, handCount: 3, splitting: true),
        Trial(wrap: false, handCount: 3, splitting: true, revival: true),
    ]

    /// その週のルールセット。ISO週番号をシードに決定的に選ばれるため、
    /// 全ユーザーが同じルールで挑戦する。難易度は常に「鬼」。
    static func config(for date: Date = .now) -> GameConfig {
        var rng = SplitMix64(state: seed(for: date))
        let trial = trials[Int(rng.next() % UInt64(trials.count))]

        var config = GameConfig()
        config.gameMode = .vsAI
        config.aiDifficulty = .oni
        config.aiLevel = nil
        config.isWeeklyChallenge = true
        config.isOverflowWrapEnabled = trial.wrap
        config.handCount = trial.handCount
        config.isSplittingEnabled = trial.splitting
        config.isDeadHandRevivalEnabled = trial.revival
        config.isBombEnabled = trial.bomb
        config.isDoubleTapEnabled = trial.doubleTap
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
