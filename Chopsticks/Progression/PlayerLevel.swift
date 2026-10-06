import Foundation

/// プレイヤー経験値とレベル・称号。モードを問わず遊ぶたびに積み上がる長期目標。
enum PlayerLevel {
    static let maxLevel = 50

    /// レベルnに到達するために必要な累計XP（Lv.2=50, Lv.3=150, Lv.5=500, Lv.10=2250, Lv.20=9500）
    static func xpRequired(forLevel level: Int) -> Int {
        let n = max(1, level)
        return 25 * n * (n - 1)
    }

    static func level(forXP xp: Int) -> Int {
        var level = 1
        while level < maxLevel && xp >= xpRequired(forLevel: level + 1) {
            level += 1
        }
        return level
    }

    /// 現在レベル内の進捗（0.0〜1.0）。最大レベルでは常に1.0。
    static func progress(forXP xp: Int) -> Double {
        let level = level(forXP: xp)
        guard level < maxLevel else { return 1 }
        let start = xpRequired(forLevel: level)
        let end = xpRequired(forLevel: level + 1)
        return Double(xp - start) / Double(end - start)
    }

    static func xpToNextLevel(forXP xp: Int) -> Int? {
        let level = level(forXP: xp)
        guard level < maxLevel else { return nil }
        return xpRequired(forLevel: level + 1) - xp
    }

    /// レベルに応じた称号
    static func title(forLevel level: Int) -> String {
        switch level {
        case ..<3: "見習い"
        case ..<5: "指使い"
        case ..<8: "割り箸使い"
        case ..<12: "達人"
        case ..<16: "師範"
        case ..<20: "名人"
        case ..<25: "鉄人"
        case ..<30: "伝説"
        default: "割り箸の神"
        }
    }

    /// 次の称号に変わるレベル（最高称号ならnil）
    static func nextTitleLevel(after level: Int) -> Int? {
        [3, 5, 8, 12, 16, 20, 25, 30].first { $0 > level }
    }

    // MARK: - XP報酬

    /// ゲーム結果に対するXP。勝敗・モード・CPUレベル・特殊条件で変わる。
    static func xpReward(for summary: GameSummary, rankLevel: Int) -> Int {
        var xp: Int
        switch summary.mode {
        case .vsAI:
            switch summary.outcome {
            case .win:
                if let level = summary.config.aiLevel {
                    xp = 20 + 6 * level
                } else {
                    xp = summary.config.aiDifficulty == .hard ? 30 : 12
                }
            case .loss: xp = 6
            case .draw: xp = 10
            case .completed: xp = 8
            }
        case .localTwoPlayer:
            xp = 12
        case .online, .nearby:
            switch summary.outcome {
            case .win: xp = 40
            case .loss: xp = 12
            case .draw, .completed: xp = 16
            }
        }
        if summary.isWin && summary.config.isDailyChallenge { xp += 50 }
        if summary.isWin && summary.isPerfect { xp += 10 }
        if summary.isWin && summary.isComeback { xp += 15 }
        if summary.isWin && summary.config.hasSpecialRules { xp += 5 }
        return xp
    }
}
