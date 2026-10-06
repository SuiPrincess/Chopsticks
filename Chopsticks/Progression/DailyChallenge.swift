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

    /// "yyyy-MM-dd"。ユーザーのカレンダー（和暦・仏暦など）に左右されないよう、年月日は常に西暦で数える。
    /// タイムゾーンだけはユーザーのものを使う（日付の切り替わりは端末のローカル時間）。
    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let c = gregorian.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func forDate(_ date: Date, calendar: Calendar = .current) -> DailyChallenge {
        forDayKey(dayKey(for: date, calendar: calendar))
    }

    /// 同じ日付キーなら、誰の端末でも・どのOSバージョンでも同じ内容になる（自前のシード付き乱数のみを使う）。
    static func forDayKey(_ key: String) -> DailyChallenge {
        var rng = SeededGenerator(seed: stableHash(key))

        var config = GameConfig()
        config.gameMode = .vsAI
        config.isDailyChallenge = true

        // 先手でも後手でも序盤で勝負が決まらないと確かめた組み合わせだけから選ぶ
        let rules = FairRuleSets.all[rng.next(in: 0...(FairRuleSets.all.count - 1))]
        FairRuleSets.apply(rules, to: &config)

        let level = rng.next(in: 3...8)
        config.aiLevel = level

        let suffixes = ["の試練", "デー", "バトル", "の洗礼", "チャレンジ"]
        let title = FairRuleSets.name(for: rules) + suffixes[rng.next(in: 0...(suffixes.count - 1))]
        return DailyChallenge(dayKey: key, config: config, cpuLevel: level, title: title)
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

    /// 範囲への割り当ても自前で行う（標準ライブラリの実装に依存しない）
    mutating func next(in range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }
}
