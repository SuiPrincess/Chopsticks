import Foundation
import Observation

/// 1ゲームを記録した結果（リザルト演出用）
struct GameRewards: Equatable {
    var xpGained: Int = 0
    var leveledUp: Bool = false
    var newTitle: String?
    var rankedUp: Bool = false
    var newStreakRecord: Bool = false
    var dailyChallengeCleared: Bool = false
    var maxLevelWin: Bool = false
}

/// 戦績・進行度。UserDefaultsに永続化し、連勝・ランク・XP・デイリーで再戦を促す。
/// `defaults`と`now`は注入可能（テスト用）。
@Observable
@MainActor
final class GameStats {
    static let shared = GameStats()
    static let maxRankLevel = 10

    // CPU戦
    private(set) var wins: Int
    private(set) var losses: Int
    private(set) var currentStreak: Int
    private(set) var bestStreak: Int
    /// ランク戦のCPUレベル（1〜maxRankLevel）。必要な★を集めると上がる。
    private(set) var rankLevel: Int
    /// 現在のレベルで集めた★（勝利で+1、敗北で-1、0未満にはならない）
    private(set) var rankStars: Int
    /// 現在のレベルでの連続敗北数（負け続けるとCPUが少し手加減する）
    private(set) var lossStreakAtLevel: Int
    /// Lv.MAX到達後の勝利数（終わりのない目標）
    private(set) var maxLevelWins: Int

    // 全モード
    private(set) var totalGames: Int
    private(set) var localGames: Int
    private(set) var multiplayerGames: Int
    private(set) var multiplayerWins: Int
    private(set) var perfectWins: Int
    private(set) var fastestWinTurns: Int?

    // 継続
    private(set) var dailyStreak: Int
    private(set) var bestDailyStreak: Int
    private(set) var lastPlayDay: Date?
    private(set) var dailyChallengeClears: Int
    private(set) var lastDailyChallengeClearKey: String?

    // 成長
    private(set) var xp: Int

    /// 直近の記録で自己ベスト連勝を更新したか
    private(set) var didSetNewRecord = false

    private let defaults: UserDefaults
    private let now: () -> Date
    private let calendar: Calendar

    private enum Key {
        static let wins = "stats.cpu.wins"
        static let losses = "stats.cpu.losses"
        static let streak = "stats.cpu.streak"
        static let bestStreak = "stats.cpu.bestStreak"
        static let rankLevel = "stats.rank.level"
        static let rankStars = "stats.rank.stars"
        static let lossStreakAtLevel = "stats.rank.lossStreakAtLevel"
        static let maxLevelWins = "stats.rank.maxLevelWins"
        static let totalGames = "stats.total.games"
        static let localGames = "stats.local.games"
        static let multiplayerGames = "stats.mp.games"
        static let multiplayerWins = "stats.mp.wins"
        static let perfectWins = "stats.perfectWins"
        static let fastestWinTurns = "stats.fastestWinTurns"
        static let dailyStreak = "stats.daily.streak"
        static let bestDailyStreak = "stats.daily.bestStreak"
        static let lastPlayDay = "stats.daily.lastPlayDay"
        static let dailyChallengeClears = "stats.dailyChallenge.clears"
        static let lastDailyChallengeClearKey = "stats.dailyChallenge.lastClearKey"
        static let xp = "stats.xp"
        static let reviewedVersion = "review.requestedVersion"
        static let allKeys = [
            wins, losses, streak, bestStreak, rankLevel, rankStars, lossStreakAtLevel, maxLevelWins, totalGames, localGames,
            multiplayerGames, multiplayerWins, perfectWins, fastestWinTurns, dailyStreak,
            bestDailyStreak, lastPlayDay, dailyChallengeClears, lastDailyChallengeClearKey, xp,
        ]
    }

    init(defaults: UserDefaults = AppDefaults.store, calendar: Calendar = .autoupdatingCurrent, now: @escaping () -> Date = { Date() }) {
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
        let storedWins = defaults.integer(forKey: Key.wins)
        let storedLosses = defaults.integer(forKey: Key.losses)
        wins = storedWins
        losses = storedLosses
        currentStreak = defaults.integer(forKey: Key.streak)
        bestStreak = defaults.integer(forKey: Key.bestStreak)
        rankLevel = min(Self.maxRankLevel, max(1, defaults.integer(forKey: Key.rankLevel)))
        rankStars = max(0, defaults.integer(forKey: Key.rankStars))
        lossStreakAtLevel = max(0, defaults.integer(forKey: Key.lossStreakAtLevel))
        maxLevelWins = defaults.integer(forKey: Key.maxLevelWins)
        // 旧バージョンからの移行: 通算が未保存ならCPU戦の合計を使う
        let storedTotal = defaults.integer(forKey: Key.totalGames)
        totalGames = max(storedTotal, storedWins + storedLosses)
        localGames = defaults.integer(forKey: Key.localGames)
        multiplayerGames = defaults.integer(forKey: Key.multiplayerGames)
        multiplayerWins = defaults.integer(forKey: Key.multiplayerWins)
        perfectWins = defaults.integer(forKey: Key.perfectWins)
        let fastest = defaults.integer(forKey: Key.fastestWinTurns)
        fastestWinTurns = fastest > 0 ? fastest : nil
        let storedDailyStreak = defaults.integer(forKey: Key.dailyStreak)
        dailyStreak = storedDailyStreak
        bestDailyStreak = max(defaults.integer(forKey: Key.bestDailyStreak), storedDailyStreak)
        lastPlayDay = defaults.object(forKey: Key.lastPlayDay) as? Date
        dailyChallengeClears = defaults.integer(forKey: Key.dailyChallengeClears)
        lastDailyChallengeClearKey = defaults.string(forKey: Key.lastDailyChallengeClearKey)
        xp = defaults.integer(forKey: Key.xp)
    }

    // MARK: - 派生値

    var playerLevel: Int { PlayerLevel.level(forXP: xp) }
    var playerTitle: String { PlayerLevel.title(forLevel: playerLevel) }
    var levelProgress: Double { PlayerLevel.progress(forXP: xp) }
    var xpToNextLevel: Int? { PlayerLevel.xpToNextLevel(forXP: xp) }
    var isRankMaxed: Bool { rankLevel >= Self.maxRankLevel }
    var hasPlayed: Bool { totalGames > 0 }

    /// レベルを上げるのに必要な★の数（序盤は1勝、終盤は3勝）
    static func starsRequired(forLevel level: Int) -> Int {
        switch level {
        case ..<4: 1
        case ..<8: 2
        default: 3
        }
    }

    var starsRequiredForCurrentLevel: Int { Self.starsRequired(forLevel: rankLevel) }

    /// 負け続けているプレイヤーへの手加減（CPUのランダム行動率に上乗せ。最大+30%）
    var mercyBoost: Double {
        guard lossStreakAtLevel >= 3 else { return 0 }
        return min(0.3, 0.1 * Double(lossStreakAtLevel - 2))
    }

    /// 表示用の連続日数。2日以上空いていたら0（記録は次のプレイで1から再開）
    var effectiveDailyStreak: Int {
        guard let last = lastPlayDay else { return 0 }
        let lastDay = calendar.startOfDay(for: last)
        let today = calendar.startOfDay(for: now())
        let gap = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
        return (gap == 0 || gap == 1) ? dailyStreak : 0
    }

    var winRate: Double? {
        let games = wins + losses
        guard games > 0 else { return nil }
        return Double(wins) / Double(games)
    }

    /// 今日すでに遊んだか（連続日数が今日の分まで加算済みか）
    var hasPlayedToday: Bool {
        guard let last = lastPlayDay else { return false }
        return calendar.isDate(last, inSameDayAs: now())
    }

    /// 連続プレイ日数が「今日遊ばないと途切れる」状態か
    var isDailyStreakAtRisk: Bool {
        guard dailyStreak >= 1, let last = lastPlayDay else { return false }
        let lastDay = calendar.startOfDay(for: last)
        let today = calendar.startOfDay(for: now())
        let gap = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
        return gap == 1
    }

    /// 今日のデイリーチャレンジ
    var todaysChallenge: DailyChallenge { DailyChallenge.forDate(now(), calendar: calendar) }

    var hasClearedTodaysChallenge: Bool {
        lastDailyChallengeClearKey == DailyChallenge.dayKey(for: now(), calendar: calendar)
    }

    // MARK: - 記録

    /// 1ゲームを記録し、XP・レベル・ランク・デイリーの結果を返す。
    @discardableResult
    func record(_ summary: GameSummary) -> GameRewards {
        var rewards = GameRewards()
        didSetNewRecord = false
        totalGames += 1
        recordDailyPlay()

        switch summary.mode {
        case .vsAI:
            switch summary.outcome {
            case .win:
                wins += 1
                currentStreak += 1
                if currentStreak > bestStreak {
                    bestStreak = currentStreak
                    // 初勝利を「記録更新」と騒がない
                    didSetNewRecord = bestStreak >= 2
                    rewards.newStreakRecord = didSetNewRecord
                }
                if summary.config.isRanked {
                    lossStreakAtLevel = 0
                    if rankLevel < Self.maxRankLevel {
                        rankStars += 1
                        if rankStars >= starsRequiredForCurrentLevel {
                            rankLevel += 1
                            rankStars = 0
                            rewards.rankedUp = true
                        }
                    } else {
                        maxLevelWins += 1
                        rewards.maxLevelWin = true
                    }
                }
                if summary.config.isDailyChallenge {
                    // 「今日の内容」と同じ条件で遊んだ勝利だけを今日のクリアにする
                    // （前日から持ち越した対戦や、日をまたいだ対戦は対象外）
                    let today = DailyChallenge.forDate(now(), calendar: calendar)
                    if summary.config == today.config, lastDailyChallengeClearKey != today.dayKey {
                        lastDailyChallengeClearKey = today.dayKey
                        dailyChallengeClears += 1
                        rewards.dailyChallengeCleared = true
                    }
                }
            case .loss:
                losses += 1
                currentStreak = 0
                if summary.config.isRanked {
                    rankStars = max(0, rankStars - 1)
                    lossStreakAtLevel += 1
                }
            case .draw, .completed:
                break
            }
        case .localTwoPlayer:
            localGames += 1
        case .online, .nearby:
            multiplayerGames += 1
            if summary.isWin { multiplayerWins += 1 }
        }

        if summary.isWin {
            if summary.isPerfect { perfectWins += 1 }
            if fastestWinTurns == nil || summary.turnCount < fastestWinTurns! {
                fastestWinTurns = summary.turnCount
            }
        }

        // XP（デイリーの重複クリアにはボーナスを付けない）
        var gained = PlayerLevel.xpReward(for: summary, rankLevel: rankLevel)
        if summary.isWin && summary.config.isDailyChallenge && !rewards.dailyChallengeCleared {
            gained -= DailyChallenge.bonusXP
        }
        let levelBefore = playerLevel
        xp += max(0, gained)
        rewards.xpGained = max(0, gained)
        if playerLevel > levelBefore {
            rewards.leveledUp = true
            let title = playerTitle
            if title != PlayerLevel.title(forLevel: levelBefore) { rewards.newTitle = title }
        }

        save()
        return rewards
    }

    /// 途中のランク戦を破棄した（負け扱い。連勝も途切れる）
    func recordAbandonedRankedGame() {
        var config = GameConfig()
        config.gameMode = .vsAI
        config.aiLevel = rankLevel
        record(GameSummary(mode: .vsAI, outcome: .loss, turnCount: 0, config: config))
    }

    /// 実績解除などの追加XP
    func addXP(_ amount: Int) {
        guard amount > 0 else { return }
        xp += amount
        save()
    }

    /// 旧API互換（CPU戦の勝敗のみ）
    func recordGame(playerWon: Bool) {
        var config = GameConfig()
        config.gameMode = .vsAI
        record(GameSummary(mode: .vsAI, outcome: playerWon ? .win : .loss, turnCount: 0, config: config))
    }

    /// 1日1回以上遊ぶと連続日数が伸びる。間が空いたら1にリセット。
    func recordDailyPlay() {
        let today = calendar.startOfDay(for: now())
        if let last = lastPlayDay {
            let lastDay = calendar.startOfDay(for: last)
            let gap = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if gap == 1 {
                dailyStreak += 1
            } else if gap > 1 || gap < 0 {
                dailyStreak = 1
            } else if dailyStreak == 0 {
                dailyStreak = 1
            }
        } else {
            dailyStreak = 1
        }
        bestDailyStreak = max(bestDailyStreak, dailyStreak)
        lastPlayDay = now()
        save()
    }

    /// 全戦績を消去（設定画面から・確認後）
    func resetAll() {
        for key in Key.allKeys { defaults.removeObject(forKey: key) }
        wins = 0; losses = 0; currentStreak = 0; bestStreak = 0
        rankLevel = 1; rankStars = 0; lossStreakAtLevel = 0; maxLevelWins = 0
        totalGames = 0; localGames = 0; multiplayerGames = 0; multiplayerWins = 0
        perfectWins = 0; fastestWinTurns = nil
        dailyStreak = 0; bestDailyStreak = 0; lastPlayDay = nil
        dailyChallengeClears = 0; lastDailyChallengeClearKey = nil
        xp = 0
        didSetNewRecord = false
    }

    // MARK: - レビュー依頼（バージョンごとに1回、気分が良い瞬間だけ）
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    /// 気分が良い「出来事」の直後だけ、バージョンごとに1回レビューを依頼する
    /// （状態ではなくイベントで判定するので、条件を満たし続けても毎回は出ない）
    func shouldRequestReview(after rewards: GameRewards) -> Bool {
        guard defaults.string(forKey: Key.reviewedVersion) != appVersion else { return false }
        if rewards.rankedUp && rankLevel >= 4 { return true }
        if rewards.newStreakRecord && currentStreak >= 3 { return true }
        if rewards.dailyChallengeCleared && dailyChallengeClears >= 2 { return true }
        return false
    }

    func markReviewRequested() {
        defaults.set(appVersion, forKey: Key.reviewedVersion)
    }

    private func save() {
        defaults.set(wins, forKey: Key.wins)
        defaults.set(losses, forKey: Key.losses)
        defaults.set(currentStreak, forKey: Key.streak)
        defaults.set(bestStreak, forKey: Key.bestStreak)
        defaults.set(rankLevel, forKey: Key.rankLevel)
        defaults.set(rankStars, forKey: Key.rankStars)
        defaults.set(lossStreakAtLevel, forKey: Key.lossStreakAtLevel)
        defaults.set(maxLevelWins, forKey: Key.maxLevelWins)
        defaults.set(totalGames, forKey: Key.totalGames)
        defaults.set(localGames, forKey: Key.localGames)
        defaults.set(multiplayerGames, forKey: Key.multiplayerGames)
        defaults.set(multiplayerWins, forKey: Key.multiplayerWins)
        defaults.set(perfectWins, forKey: Key.perfectWins)
        defaults.set(fastestWinTurns ?? 0, forKey: Key.fastestWinTurns)
        defaults.set(dailyStreak, forKey: Key.dailyStreak)
        defaults.set(bestDailyStreak, forKey: Key.bestDailyStreak)
        if let lastPlayDay {
            defaults.set(lastPlayDay, forKey: Key.lastPlayDay)
        }
        defaults.set(dailyChallengeClears, forKey: Key.dailyChallengeClears)
        defaults.set(lastDailyChallengeClearKey, forKey: Key.lastDailyChallengeClearKey)
        defaults.set(xp, forKey: Key.xp)
    }
}
