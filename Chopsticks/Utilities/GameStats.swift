import Foundation
import Observation

/// CPU対戦の戦績。UserDefaultsに永続化し、連勝ストリークで再戦を促す。
@Observable
@MainActor
final class GameStats {
    static let shared = GameStats()
    static let maxRankLevel = 10

    private(set) var wins: Int
    private(set) var losses: Int
    private(set) var currentStreak: Int
    private(set) var bestStreak: Int
    /// ランク戦のCPUレベル（1〜maxRankLevel）。勝つと上がる。
    private(set) var rankLevel: Int
    /// 連続プレイ日数
    private(set) var dailyStreak: Int
    private var lastPlayDay: Date?
    /// 直近の記録で自己ベスト連勝を更新したか
    private(set) var didSetNewRecord = false

    private enum Key {
        static let wins = "stats.cpu.wins"
        static let losses = "stats.cpu.losses"
        static let streak = "stats.cpu.streak"
        static let bestStreak = "stats.cpu.bestStreak"
        static let rankLevel = "stats.rank.level"
        static let dailyStreak = "stats.daily.streak"
        static let lastPlayDay = "stats.daily.lastPlayDay"
        static let reviewedVersion = "review.requestedVersion"
    }

    private init() {
        let defaults = UserDefaults.standard
        wins = defaults.integer(forKey: Key.wins)
        losses = defaults.integer(forKey: Key.losses)
        currentStreak = defaults.integer(forKey: Key.streak)
        bestStreak = defaults.integer(forKey: Key.bestStreak)
        rankLevel = max(1, defaults.integer(forKey: Key.rankLevel))
        dailyStreak = defaults.integer(forKey: Key.dailyStreak)
        lastPlayDay = defaults.object(forKey: Key.lastPlayDay) as? Date
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

    /// ランク戦で勝利したらレベルを上げる。上がったらtrue。
    func registerRankedWin() -> Bool {
        guard rankLevel < Self.maxRankLevel else { return false }
        rankLevel += 1
        save()
        return true
    }

    /// 1日1回以上遊ぶと連続日数が伸びる。間が空いたら1にリセット。
    func recordDailyPlay() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        if let last = lastPlayDay {
            let lastDay = calendar.startOfDay(for: last)
            let gap = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if gap == 1 {
                dailyStreak += 1
            } else if gap > 1 {
                dailyStreak = 1
            }
        } else {
            dailyStreak = 1
        }
        lastPlayDay = .now
        save()
    }

    // MARK: - レビュー依頼（バージョンごとに1回、気分が良い瞬間だけ）
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    func shouldRequestReview() -> Bool {
        guard UserDefaults.standard.string(forKey: Key.reviewedVersion) != appVersion else { return false }
        return currentStreak >= 3 || rankLevel >= 3
    }

    func markReviewRequested() {
        UserDefaults.standard.set(appVersion, forKey: Key.reviewedVersion)
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(wins, forKey: Key.wins)
        defaults.set(losses, forKey: Key.losses)
        defaults.set(currentStreak, forKey: Key.streak)
        defaults.set(bestStreak, forKey: Key.bestStreak)
        defaults.set(rankLevel, forKey: Key.rankLevel)
        defaults.set(dailyStreak, forKey: Key.dailyStreak)
        if let lastPlayDay {
            defaults.set(lastPlayDay, forKey: Key.lastPlayDay)
        }
    }
}
