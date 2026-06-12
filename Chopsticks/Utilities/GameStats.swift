import Foundation
import Observation

/// CPU対戦の戦績。UserDefaultsに永続化し、連勝ストリークで再戦を促す。
@Observable
@MainActor
final class GameStats {
    static let shared = GameStats()

    private(set) var wins: Int
    private(set) var losses: Int
    private(set) var currentStreak: Int
    private(set) var bestStreak: Int
    /// 直近の記録で自己ベスト連勝を更新したか
    private(set) var didSetNewRecord = false

    private enum Key {
        static let wins = "stats.cpu.wins"
        static let losses = "stats.cpu.losses"
        static let streak = "stats.cpu.streak"
        static let bestStreak = "stats.cpu.bestStreak"
    }

    private init() {
        let defaults = UserDefaults.standard
        wins = defaults.integer(forKey: Key.wins)
        losses = defaults.integer(forKey: Key.losses)
        currentStreak = defaults.integer(forKey: Key.streak)
        bestStreak = defaults.integer(forKey: Key.bestStreak)
    }

    func recordGame(playerWon: Bool) {
        didSetNewRecord = false
        if playerWon {
            wins += 1
            currentStreak += 1
            if currentStreak > bestStreak {
                bestStreak = currentStreak
                // 初勝利を「記録更新」と騒がない
                didSetNewRecord = bestStreak >= 2
            }
        } else {
            losses += 1
            currentStreak = 0
        }
        save()
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(wins, forKey: Key.wins)
        defaults.set(losses, forKey: Key.losses)
        defaults.set(currentStreak, forKey: Key.streak)
        defaults.set(bestStreak, forKey: Key.bestStreak)
    }
}
