import Foundation

/// 日替わりチャレンジ。日付をシードにルールとCPUレベルを決めるので、
/// 同じ日は誰が遊んでも同じ条件になる（共有・会話のネタになる）。
struct DailyChallenge: Equatable {
    /// "yyyy-MM-dd"（端末のローカル日付）
    let dayKey: String
    let config: GameConfig
    let cpuLevel: Int
    let title: String
    /// 報酬XP（通常の勝利XPに上乗せ）
    static let bonusXP = 50

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func forDate(_ date: Date, calendar: Calendar = .current) -> DailyChallenge {
        let key = dayKey(for: date, calendar: calendar)
        return forDayKey(key)
    }

    static func forDayKey(_ key: String) -> DailyChallenge {
        var rng = SeededGenerator(seed: UInt64(truncatingIfNeeded: stableHash(key)))

        var config = GameConfig()
        config.gameMode = .vsAI
        config.isDailyChallenge = true

        // 特殊ルールを1〜2個。毎日違う組み合わせになるよう重みづけ。
        let specials = ["poison", "bomb", "mirror", "double", "split", "three"].shuffled(using: &rng)
        let count = rng.next(in: 1...2)
        for rule in specials.prefix(count) {
            switch rule {
            case "poison": config.isPoisonEnabled = true
            case "bomb": config.isBombEnabled = true
            case "mirror": config.isMirrorEnabled = true
            case "double": config.isDoubleTapEnabled = true
            case "split":
                config.isSplittingEnabled = true
                config.isDeadHandRevivalEnabled = rng.next(in: 0...2) == 0
            default: config.handCount = 3
            }
        }
        config.isOverflowWrapEnabled = rng.next(in: 0...4) != 0  // 2割でクラシック

        let level = rng.next(in: 3...8)
        config.aiLevel = level

        let title = Self.title(for: config, rng: &rng)
        return DailyChallenge(dayKey: key, config: config, cpuLevel: level, title: title)
    }

    private static func title(for config: GameConfig, rng: inout SeededGenerator) -> String {
        var parts: [String] = []
        if config.isPoisonEnabled { parts.append("毒") }
        if config.isBombEnabled { parts.append("爆弾") }
        if config.isMirrorEnabled { parts.append("ミラー") }
        if config.isDoubleTapEnabled { parts.append("連撃") }
        if config.isSplittingEnabled { parts.append("分割") }
        if config.handCount == 3 { parts.append("三本手") }
        let suffixes = ["の試練", "デー", "バトル", "の洗礼", "チャレンジ"]
        let suffix = suffixes[rng.next(in: 0...(suffixes.count - 1))]
        return parts.joined(separator: "×") + suffix
    }

    /// 文字列から決定論的な64bitハッシュ（Swiftの`hashValue`はプロセスごとに変わるため使わない）
    static func stableHash(_ string: String) -> UInt64 {
        // FNV-1a
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}

/// SplitMix64。`RandomNumberGenerator`準拠なので`shuffled(using:)`等にそのまま使える。
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func next(in range: ClosedRange<Int>) -> Int {
        Int.random(in: range, using: &self)
    }
}
