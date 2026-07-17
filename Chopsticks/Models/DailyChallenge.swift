import Foundation

/// 日付から決定的に生成される乱数（全ユーザーが同じ日替わりルールになる）
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// 🎯 今日の挑戦: 日替わりの特殊ルールでCPU（つよい）に勝つ。1日1回。
enum DailyChallenge {

    /// その日のルールセット。日付をシードに決定的に生成されるため、
    /// 全ユーザーが同じルールで挑戦する。
    static func config(for date: Date = .now) -> GameConfig {
        var rng = SplitMix64(state: seed(for: date))
        func chance(_ probability: Double) -> Bool {
            Double.random(in: 0..<1, using: &rng) < probability
        }

        var config = GameConfig()
        config.gameMode = .vsAI
        config.aiDifficulty = .hard
        config.aiLevel = nil
        config.isDailyChallenge = true

        config.isOverflowWrapEnabled = chance(0.7)
        config.isSplittingEnabled = chance(0.5)
        config.isDeadHandRevivalEnabled = config.isSplittingEnabled && chance(0.4)
        config.handCount = chance(0.25) ? 3 : 2
        config.isPoisonEnabled = chance(0.3)
        config.isBombEnabled = chance(0.3)
        config.isMirrorEnabled = chance(0.3)
        config.isDoubleTapEnabled = chance(0.3)

        // 全部OFFの日は退屈なので、どれか1つは必ず入れる
        if !config.isSplittingEnabled && !config.isPoisonEnabled
            && !config.isBombEnabled && !config.isMirrorEnabled
            && !config.isDoubleTapEnabled {
            switch Int.random(in: 0..<5, using: &rng) {
            case 0: config.isSplittingEnabled = true
            case 1: config.isPoisonEnabled = true
            case 2: config.isBombEnabled = true
            case 3: config.isMirrorEnabled = true
            default: config.isDoubleTapEnabled = true
            }
        }

        // 毒の退化対策: 開始時は全手が指1本＝全タップが毒相討ちのため、
        // 2本手の毒は最適応答で自明な勝敗に崩壊する。3本手＋分割を強制する。
        if config.isPoisonEnabled {
            config.handCount = 3
            config.isSplittingEnabled = true
        }
        return config
    }

    /// メニュー表示用の日付（例: "7/17"）
    static func title(for date: Date = .now) -> String {
        let components = Calendar.current.dateComponents([.month, .day], from: date)
        return "\(components.month ?? 0)/\(components.day ?? 0)"
    }

    private static func seed(for date: Date) -> UInt64 {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let day = (components.year ?? 0) * 10_000
            + (components.month ?? 0) * 100
            + (components.day ?? 0)
        return UInt64(day)
    }
}
