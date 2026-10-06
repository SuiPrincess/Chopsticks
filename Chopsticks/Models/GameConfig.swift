import Foundation

enum GameMode: String, Equatable, Codable, Sendable {
    case localTwoPlayer
    case vsAI
    case online
    case nearby
}

enum AIDifficulty: String, CaseIterable, Equatable, Codable, Sendable {
    case easy
    case hard

    var label: String {
        switch self {
        case .easy: "かんたん"
        case .hard: "つよい"
        }
    }
}

struct GameConfig: Equatable, Codable, Sendable {
    // 基本
    var isSplittingEnabled: Bool = false
    var isOverflowWrapEnabled: Bool = true
    var isDeadHandRevivalEnabled: Bool = false
    var handCount: Int = 2

    // モード
    var gameMode: GameMode = .localTwoPlayer
    var aiDifficulty: AIDifficulty = .easy
    /// ランク戦のCPUレベル（1〜10）。nilならフリー対戦（aiDifficultyを使用）。
    var aiLevel: Int? = nil
    /// デイリーチャレンジ（日替わりの固定ルール・報酬は1日1回）
    var isDailyChallenge: Bool = false

    // エキセントリックルール
    var isPoisonEnabled: Bool = false
    var isBombEnabled: Bool = false
    var isMirrorEnabled: Bool = false
    var isDoubleTapEnabled: Bool = false

    var isMultiplayer: Bool {
        gameMode == .online || gameMode == .nearby
    }

    /// ランク戦（ラダー）か
    var isRanked: Bool {
        gameMode == .vsAI && aiLevel != nil && !isDailyChallenge
    }

    /// 標準ルール（ループあり・分割なし・特殊ルールなし・2本手）か
    var isStandardRules: Bool {
        isOverflowWrapEnabled && !isSplittingEnabled && !isDeadHandRevivalEnabled
            && handCount == 2 && !hasSpecialRules
    }

    var hasSpecialRules: Bool {
        isPoisonEnabled || isBombEnabled || isMirrorEnabled || isDoubleTapEnabled
    }

    /// 有効なルールの短いラベル（メニュー・リザルト・共有文で使用）
    var activeRuleLabels: [String] {
        var labels: [String] = []
        if isOverflowWrapEnabled { labels.append("ループ") }
        if isSplittingEnabled { labels.append("分割") }
        if isDeadHandRevivalEnabled { labels.append("復活") }
        if handCount == 3 { labels.append("3本手") }
        if isPoisonEnabled { labels.append("毒") }
        if isBombEnabled { labels.append("爆弾") }
        if isMirrorEnabled { labels.append("ミラー") }
        if isDoubleTapEnabled { labels.append("2回攻撃") }
        return labels
    }

    init() {}

    // MARK: - Codable（将来フィールドを追加しても古い保存データ・旧バージョンの対戦相手と互換を保つ）
    private enum CodingKeys: String, CodingKey {
        case isSplittingEnabled, isOverflowWrapEnabled, isDeadHandRevivalEnabled, handCount
        case gameMode, aiDifficulty, aiLevel, isDailyChallenge
        case isPoisonEnabled, isBombEnabled, isMirrorEnabled, isDoubleTapEnabled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isSplittingEnabled = try c.decodeIfPresent(Bool.self, forKey: .isSplittingEnabled) ?? false
        isOverflowWrapEnabled = try c.decodeIfPresent(Bool.self, forKey: .isOverflowWrapEnabled) ?? true
        isDeadHandRevivalEnabled = try c.decodeIfPresent(Bool.self, forKey: .isDeadHandRevivalEnabled) ?? false
        handCount = try c.decodeIfPresent(Int.self, forKey: .handCount) ?? 2
        gameMode = try c.decodeIfPresent(GameMode.self, forKey: .gameMode) ?? .localTwoPlayer
        aiDifficulty = try c.decodeIfPresent(AIDifficulty.self, forKey: .aiDifficulty) ?? .easy
        aiLevel = try c.decodeIfPresent(Int.self, forKey: .aiLevel)
        isDailyChallenge = try c.decodeIfPresent(Bool.self, forKey: .isDailyChallenge) ?? false
        isPoisonEnabled = try c.decodeIfPresent(Bool.self, forKey: .isPoisonEnabled) ?? false
        isBombEnabled = try c.decodeIfPresent(Bool.self, forKey: .isBombEnabled) ?? false
        isMirrorEnabled = try c.decodeIfPresent(Bool.self, forKey: .isMirrorEnabled) ?? false
        isDoubleTapEnabled = try c.decodeIfPresent(Bool.self, forKey: .isDoubleTapEnabled) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(isSplittingEnabled, forKey: .isSplittingEnabled)
        try c.encode(isOverflowWrapEnabled, forKey: .isOverflowWrapEnabled)
        try c.encode(isDeadHandRevivalEnabled, forKey: .isDeadHandRevivalEnabled)
        try c.encode(handCount, forKey: .handCount)
        try c.encode(gameMode, forKey: .gameMode)
        try c.encode(aiDifficulty, forKey: .aiDifficulty)
        try c.encodeIfPresent(aiLevel, forKey: .aiLevel)
        try c.encode(isDailyChallenge, forKey: .isDailyChallenge)
        try c.encode(isPoisonEnabled, forKey: .isPoisonEnabled)
        try c.encode(isBombEnabled, forKey: .isBombEnabled)
        try c.encode(isMirrorEnabled, forKey: .isMirrorEnabled)
        try c.encode(isDoubleTapEnabled, forKey: .isDoubleTapEnabled)
    }
}
