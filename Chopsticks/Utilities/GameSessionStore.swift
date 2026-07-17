import Foundation
import Observation

/// 中断したゲームのスナップショット
struct SavedGame: Codable {
    var state: GameState
    /// ダブルタップルールで1回目の攻撃を終えた状態を復元するため
    var attacksThisTurn: Int
    var savedAt: Date
}

/// 進行中のゲームをUserDefaultsへ自動保存し、メニューの「続きから」を支える。
/// マルチプレイは相手側の状態を復元できないため対象外。
@Observable
@MainActor
final class GameSessionStore {
    static let shared = GameSessionStore(defaults: .standard)

    private let defaults: UserDefaults

    private(set) var savedGame: SavedGame?

    private static let key = "savedGame.v1"

    init(defaults: UserDefaults) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(SavedGame.self, from: data) {
            savedGame = saved
        }
    }

    /// 進行中（1手以上進んだ・非マルチプレイ）のゲームだけ保存する
    func save(state: GameState, attacksThisTurn: Int) {
        guard case .playing = state.phase,
              state.turnCount > 0 || attacksThisTurn > 0,
              !state.config.isMultiplayer
        else { return }
        let saved = SavedGame(state: state, attacksThisTurn: attacksThisTurn, savedAt: .now)
        guard let data = try? JSONEncoder().encode(saved) else { return }
        defaults.set(data, forKey: Self.key)
        savedGame = saved
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
        savedGame = nil
    }

    /// メニューに表示する説明（例: "CPU Lv.3・ターン12"）
    var resumeDescription: String? {
        guard let saved = savedGame else { return nil }
        let config = saved.state.config
        let mode: String
        switch config.gameMode {
        case .vsAI:
            if config.isDailyChallenge {
                mode = String(localized: "今日の挑戦")
            } else if config.isWeeklyChallenge {
                mode = String(localized: "今週の試練")
            } else if let level = config.aiLevel {
                mode = String(localized: "ランク戦 Lv.\(level)")
            } else {
                mode = String(localized: "CPU戦（\(config.aiDifficulty.label)）")
            }
        case .localTwoPlayer:
            mode = String(localized: "2人対戦")
        case .online, .nearby:
            return nil
        }
        return String(localized: "\(mode)・ターン\(saved.state.turnCount + 1)")
    }
}
