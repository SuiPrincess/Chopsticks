import Foundation

enum GameMode: String, Equatable, Codable {
    case localTwoPlayer
    case vsAI
    case online
    case nearby
}

enum AIDifficulty: String, CaseIterable, Equatable, Codable {
    case easy
    case hard
    case oni

    var label: String {
        switch self {
        case .easy: String(localized: "かんたん")
        case .hard: String(localized: "つよい")
        case .oni: String(localized: "鬼")
        }
    }
}

struct GameConfig: Equatable, Codable {
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
    /// 🎯 今日の挑戦（日替わりルール・1日1回クリア記録）
    var isDailyChallenge: Bool = false

    // エキセントリックルール
    var isPoisonEnabled: Bool = false
    var isBombEnabled: Bool = false
    var isMirrorEnabled: Bool = false
    var isDoubleTapEnabled: Bool = false

    var isMultiplayer: Bool {
        gameMode == .online || gameMode == .nearby
    }

    init() {}

    // MARK: - Codable
    // フィールド追加でキーが欠けていてもデフォルト値で読めるようにする。
    // 旧バージョンの中断保存や、バージョン混在のマルチプレイ
    // （旧クライアントからのgameStart等）がdecode失敗で壊れないための互換層。
    private enum CodingKeys: String, CodingKey {
        case isSplittingEnabled, isOverflowWrapEnabled, isDeadHandRevivalEnabled, handCount
        case gameMode, aiDifficulty, aiLevel, isDailyChallenge
        case isPoisonEnabled, isBombEnabled, isMirrorEnabled, isDoubleTapEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isSplittingEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSplittingEnabled) ?? false
        isOverflowWrapEnabled = try container.decodeIfPresent(Bool.self, forKey: .isOverflowWrapEnabled) ?? true
        isDeadHandRevivalEnabled = try container.decodeIfPresent(Bool.self, forKey: .isDeadHandRevivalEnabled) ?? false
        handCount = try container.decodeIfPresent(Int.self, forKey: .handCount) ?? 2
        gameMode = try container.decodeIfPresent(GameMode.self, forKey: .gameMode) ?? .localTwoPlayer
        aiDifficulty = try container.decodeIfPresent(AIDifficulty.self, forKey: .aiDifficulty) ?? .easy
        aiLevel = try container.decodeIfPresent(Int.self, forKey: .aiLevel)
        isDailyChallenge = try container.decodeIfPresent(Bool.self, forKey: .isDailyChallenge) ?? false
        isPoisonEnabled = try container.decodeIfPresent(Bool.self, forKey: .isPoisonEnabled) ?? false
        isBombEnabled = try container.decodeIfPresent(Bool.self, forKey: .isBombEnabled) ?? false
        isMirrorEnabled = try container.decodeIfPresent(Bool.self, forKey: .isMirrorEnabled) ?? false
        isDoubleTapEnabled = try container.decodeIfPresent(Bool.self, forKey: .isDoubleTapEnabled) ?? false
    }
}
