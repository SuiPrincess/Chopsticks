import Foundation

enum GameMode: Equatable {
    case localTwoPlayer
    case vsAI
}

enum AIDifficulty: String, CaseIterable, Equatable {
    case easy
    case hard

    var label: String {
        switch self {
        case .easy: "かんたん"
        case .hard: "つよい"
        }
    }
}

struct GameConfig: Equatable {
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

    // エキセントリックルール
    var isPoisonEnabled: Bool = false
    var isBombEnabled: Bool = false
    var isMirrorEnabled: Bool = false
    var isDoubleTapEnabled: Bool = false
}
