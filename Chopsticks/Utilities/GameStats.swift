import Foundation
import Observation

/// CPU対戦の戦績。UserDefaultsに永続化し、連勝ストリークで再戦を促す。
/// テストから隔離スイート＋任意日付で検証できるよう、defaultsと日付を注入可能。
@Observable
@MainActor
final class GameStats {
    static let shared = GameStats(defaults: .standard)
    static let maxRankLevel = 10

    private let defaults: UserDefaults

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
    /// 🎯 今日の挑戦を最後にクリアした日
    private(set) var lastDailyChallengeClear: Date?
    /// 🎯 今日の挑戦の通算クリア回数（1日1回までカウント。報酬テーマの解放条件）
    private(set) var dailyChallengeClearCount: Int
    /// 🔥 難易度「鬼」への通算勝利数（報酬テーマの解放条件）
    private(set) var oniWins: Int
    /// ⚔️ 今週の試練を最後にクリアした日
    private(set) var lastWeeklyChallengeClear: Date?
    /// ⚔️ 今週の試練の通算クリア回数（週1回までカウント）
    private(set) var weeklyChallengeClearCount: Int

    private enum Key {
        static let wins = "stats.cpu.wins"
        static let losses = "stats.cpu.losses"
        static let streak = "stats.cpu.streak"
        static let bestStreak = "stats.cpu.bestStreak"
        static let rankLevel = "stats.rank.level"
        static let dailyStreak = "stats.daily.streak"
        static let lastPlayDay = "stats.daily.lastPlayDay"
        static let reviewedVersion = "review.requestedVersion"
        static let dailyChallengeClear = "stats.dailyChallenge.lastClear"
        static let dailyChallengeCount = "stats.dailyChallenge.clearCount"
        static let oniWins = "stats.oniWins"
        static let weeklyChallengeClear = "stats.weeklyChallenge.lastClear"
        static let weeklyChallengeCount = "stats.weeklyChallenge.clearCount"
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        wins = defaults.integer(forKey: Key.wins)
        losses = defaults.integer(forKey: Key.losses)
        currentStreak = defaults.integer(forKey: Key.streak)
        bestStreak = defaults.integer(forKey: Key.bestStreak)
        rankLevel = max(1, defaults.integer(forKey: Key.rankLevel))
        dailyStreak = defaults.integer(forKey: Key.dailyStreak)
        lastPlayDay = defaults.object(forKey: Key.lastPlayDay) as? Date
        lastDailyChallengeClear = defaults.object(forKey: Key.dailyChallengeClear) as? Date
        dailyChallengeClearCount = defaults.integer(forKey: Key.dailyChallengeCount)
        oniWins = defaults.integer(forKey: Key.oniWins)
        lastWeeklyChallengeClear = defaults.object(forKey: Key.weeklyChallengeClear) as? Date
        weeklyChallengeClearCount = defaults.integer(forKey: Key.weeklyChallengeCount)
    }

    // MARK: - 今週の試練

    var isWeeklyChallengeClearedThisWeek: Bool {
        isWeeklyChallengeCleared(asOf: .now)
    }

    func isWeeklyChallengeCleared(asOf date: Date) -> Bool {
        guard let last = lastWeeklyChallengeClear else { return false }
        let lastWeek = WeeklyChallenge.isoWeek(for: last)
        let currentWeek = WeeklyChallenge.isoWeek(for: date)
        return lastWeek == currentWeek
    }

    /// クリアを記録する。通算回数は週1回だけ増える。
    func markWeeklyChallengeCleared(on date: Date = .now) {
        if !isWeeklyChallengeCleared(asOf: date) {
            weeklyChallengeClearCount += 1
            defaults.set(weeklyChallengeClearCount, forKey: Key.weeklyChallengeCount)
        }
        lastWeeklyChallengeClear = date
        defaults.set(lastWeeklyChallengeClear, forKey: Key.weeklyChallengeClear)
    }

    /// 🔥 難易度「鬼」への勝利を記録する（報酬テーマの解放条件）
    func recordOniWin() {
        oniWins += 1
        defaults.set(oniWins, forKey: Key.oniWins)
    }

    // MARK: - 今日の挑戦

    var isDailyChallengeClearedToday: Bool {
        isDailyChallengeCleared(asOf: .now)
    }

    func isDailyChallengeCleared(asOf date: Date) -> Bool {
        guard let last = lastDailyChallengeClear else { return false }
        return Calendar.current.isDate(last, inSameDayAs: date)
    }

    /// クリアを記録する。通算回数は1日1回だけ増える。
    func markDailyChallengeCleared(on date: Date = .now) {
        if !isDailyChallengeCleared(asOf: date) {
            dailyChallengeClearCount += 1
            defaults.set(dailyChallengeClearCount, forKey: Key.dailyChallengeCount)
        }
        lastDailyChallengeClear = date
        defaults.set(lastDailyChallengeClear, forKey: Key.dailyChallengeClear)
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
    func recordDailyPlay(on date: Date = .now) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
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
        lastPlayDay = date
        save()
    }

    // MARK: - レビュー依頼（バージョンごとに1回、気分が良い瞬間だけ）
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    func shouldRequestReview() -> Bool {
        guard defaults.string(forKey: Key.reviewedVersion) != appVersion else { return false }
        return currentStreak >= 3 || rankLevel >= 3
    }

    func markReviewRequested() {
        defaults.set(appVersion, forKey: Key.reviewedVersion)
    }

    /// 全戦績を初期化する（戦績画面の「リセット」用）
    func reset() {
        wins = 0
        losses = 0
        currentStreak = 0
        bestStreak = 0
        rankLevel = 1
        dailyStreak = 0
        lastPlayDay = nil
        didSetNewRecord = false
        lastDailyChallengeClear = nil
        defaults.removeObject(forKey: Key.dailyChallengeClear)
        dailyChallengeClearCount = 0
        defaults.removeObject(forKey: Key.dailyChallengeCount)
        oniWins = 0
        defaults.removeObject(forKey: Key.oniWins)
        lastWeeklyChallengeClear = nil
        defaults.removeObject(forKey: Key.weeklyChallengeClear)
        weeklyChallengeClearCount = 0
        defaults.removeObject(forKey: Key.weeklyChallengeCount)
        save()
    }

    private func save() {
        defaults.set(wins, forKey: Key.wins)
        defaults.set(losses, forKey: Key.losses)
        defaults.set(currentStreak, forKey: Key.streak)
        defaults.set(bestStreak, forKey: Key.bestStreak)
        defaults.set(rankLevel, forKey: Key.rankLevel)
        defaults.set(dailyStreak, forKey: Key.dailyStreak)
        if let lastPlayDay {
            defaults.set(lastPlayDay, forKey: Key.lastPlayDay)
        } else {
            defaults.removeObject(forKey: Key.lastPlayDay)
        }
    }
}
