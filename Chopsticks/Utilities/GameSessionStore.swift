import Foundation

/// 中断したゲーム（CPU戦・1台2人対戦）を保存し、次回起動時に「続きから」遊べるようにする。
struct SavedGame: Codable, Equatable {
    var state: GameState
    var attacksThisTurn: Int
    var savedAt: Date
}

enum GameSessionStore {
    private static let key = "session.savedGame"
    /// これより古い保存は破棄する
    private static let maxAge: TimeInterval = 60 * 60 * 24 * 3

    static func save(state: GameState, attacksThisTurn: Int, defaults: UserDefaults = AppDefaults.store, now: Date = Date()) {
        guard state.phase == .playing, !state.config.isMultiplayer else {
            clear(defaults: defaults)
            return
        }
        let saved = SavedGame(state: state, attacksThisTurn: attacksThisTurn, savedAt: now)
        if let data = try? JSONEncoder().encode(saved) {
            defaults.set(data, forKey: key)
        }
    }

    static func load(defaults: UserDefaults = AppDefaults.store, now: Date = Date()) -> SavedGame? {
        guard let data = defaults.data(forKey: key),
              let saved = try? JSONDecoder().decode(SavedGame.self, from: data)
        else { return nil }
        guard saved.state.phase == .playing,
              now.timeIntervalSince(saved.savedAt) < maxAge,
              now.timeIntervalSince(saved.savedAt) >= 0
        else {
            clear(defaults: defaults)
            return nil
        }
        return saved
    }

    static func clear(defaults: UserDefaults = AppDefaults.store) {
        defaults.removeObject(forKey: key)
    }
}
