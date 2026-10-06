import XCTest
@testable import Chopsticks

@MainActor
final class ProgressionTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var now: Date!
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }()

    override func setUp() async throws {
        suiteName = "ChopsticksTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 12))!
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeStats() -> GameStats {
        GameStats(defaults: defaults, calendar: calendar, now: { self.now })
    }

    private func rankedWin(level: Int, turns: Int = 12, perfect: Bool = false) -> GameSummary {
        var config = GameConfig()
        config.gameMode = .vsAI
        config.aiLevel = level
        return GameSummary(mode: .vsAI, outcome: .win, turnCount: turns, config: config, isPerfect: perfect)
    }

    private func rankedLoss(level: Int) -> GameSummary {
        var config = GameConfig()
        config.gameMode = .vsAI
        config.aiLevel = level
        return GameSummary(mode: .vsAI, outcome: .loss, turnCount: 20, config: config)
    }

    // MARK: - ランク・★

    func testRankStarsAndLevelUp() async {
        let stats = makeStats()
        XCTAssertEqual(stats.rankLevel, 1)
        var r = stats.record(rankedWin(level: 1))
        XCTAssertTrue(r.rankedUp, "Lv.1は1勝で昇格")
        XCTAssertEqual(stats.rankLevel, 2)

        stats.record(rankedWin(level: 2)); stats.record(rankedWin(level: 3))
        XCTAssertEqual(stats.rankLevel, 4)
        r = stats.record(rankedWin(level: 4))
        XCTAssertFalse(r.rankedUp, "Lv.4は2勝必要")
        XCTAssertEqual(stats.rankStars, 1)
        stats.record(rankedLoss(level: 4))
        XCTAssertEqual(stats.rankStars, 0, "負けると★が減る")
        stats.record(rankedLoss(level: 4))
        XCTAssertEqual(stats.rankStars, 0, "0未満にはならない")
        XCTAssertEqual(stats.lossStreakAtLevel, 2)
        XCTAssertEqual(stats.mercyBoost, 0)
        stats.record(rankedLoss(level: 4))
        XCTAssertGreaterThan(stats.mercyBoost, 0, "3連敗で手加減")
        stats.record(rankedWin(level: 4))
        XCTAssertEqual(stats.lossStreakAtLevel, 0)
        stats.record(rankedWin(level: 4))
        XCTAssertEqual(stats.rankLevel, 5)
    }

    func testMaxLevelWinsAfterLadder() async {
        let stats = makeStats()
        var guardCount = 0
        while !stats.isRankMaxed && guardCount < 100 {
            stats.record(rankedWin(level: stats.rankLevel))
            guardCount += 1
        }
        XCTAssertEqual(stats.rankLevel, GameStats.maxRankLevel)
        let r = stats.record(rankedWin(level: 10))
        XCTAssertTrue(r.maxLevelWin)
        XCTAssertEqual(stats.maxLevelWins, 1)
        XCTAssertEqual(stats.rankLevel, GameStats.maxRankLevel)
    }

    func testStreaksAndRecords() async {
        let stats = makeStats()
        stats.record(rankedWin(level: 1))
        XCTAssertFalse(stats.didSetNewRecord, "初勝利は記録更新と騒がない")
        stats.record(rankedWin(level: 2))
        XCTAssertTrue(stats.didSetNewRecord)
        XCTAssertEqual(stats.currentStreak, 2)
        stats.record(rankedLoss(level: 3))
        XCTAssertEqual(stats.currentStreak, 0)
        XCTAssertEqual(stats.bestStreak, 2)
        XCTAssertEqual(stats.wins, 2)
        XCTAssertEqual(stats.losses, 1)
        XCTAssertEqual(stats.totalGames, 3)
    }

    // MARK: - XP

    func testXPAndLevels() async {
        XCTAssertEqual(PlayerLevel.level(forXP: 0), 1)
        XCTAssertEqual(PlayerLevel.level(forXP: 49), 1)
        XCTAssertEqual(PlayerLevel.level(forXP: 50), 2)
        XCTAssertEqual(PlayerLevel.level(forXP: 2250), 10)
        XCTAssertEqual(PlayerLevel.xpToNextLevel(forXP: 0), 50)
        XCTAssertEqual(PlayerLevel.progress(forXP: 25), 0.5, accuracy: 0.001)
        XCTAssertEqual(PlayerLevel.title(forLevel: 1), "見習い")
        XCTAssertNotEqual(PlayerLevel.title(forLevel: 30), PlayerLevel.title(forLevel: 1))

        let stats = makeStats()
        let r = stats.record(rankedWin(level: 1, perfect: true))
        XCTAssertEqual(r.xpGained, 20 + 6 + 10)
        XCTAssertEqual(stats.xp, 36)
        stats.addXP(20)
        XCTAssertEqual(stats.playerLevel, 2)
    }

    // MARK: - 連続日数

    func testDailyStreakAcrossDays() async {
        let stats = makeStats()
        stats.record(rankedWin(level: 1))
        XCTAssertEqual(stats.dailyStreak, 1)
        XCTAssertTrue(stats.hasPlayedToday)
        stats.record(rankedWin(level: 2))
        XCTAssertEqual(stats.dailyStreak, 1, "同じ日に何回遊んでも1日")

        now = calendar.date(byAdding: .day, value: 1, to: now)
        XCTAssertTrue(stats.isDailyStreakAtRisk)
        XCTAssertEqual(stats.effectiveDailyStreak, 1)
        stats.record(rankedLoss(level: 3))
        XCTAssertEqual(stats.dailyStreak, 2)

        now = calendar.date(byAdding: .day, value: 3, to: now)
        XCTAssertEqual(stats.effectiveDailyStreak, 0, "2日以上空くと表示上は0")
        XCTAssertFalse(stats.isDailyStreakAtRisk)
        stats.record(rankedLoss(level: 3))
        XCTAssertEqual(stats.dailyStreak, 1, "途切れたら1から")
        XCTAssertEqual(stats.bestDailyStreak, 2)
    }

    func testDailyStreakSurvivesReload() async {
        var stats = makeStats()
        stats.record(rankedWin(level: 1))
        now = calendar.date(byAdding: .day, value: 1, to: now)
        stats.record(rankedWin(level: 2))
        stats = makeStats()
        XCTAssertEqual(stats.dailyStreak, 2)
        XCTAssertEqual(stats.rankLevel, 3)
        XCTAssertEqual(stats.wins, 2)
    }

    // MARK: - デイリーチャレンジ

    func testDailyChallengeIsDeterministicPerDay() async {
        let a = DailyChallenge.forDayKey("2026-10-01")
        let b = DailyChallenge.forDayKey("2026-10-01")
        let c = DailyChallenge.forDayKey("2026-10-02")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a.title + "\(a.cpuLevel)" + "\(a.config)", c.title + "\(c.cpuLevel)" + "\(c.config)")
        XCTAssertTrue(a.config.isDailyChallenge)
        XCTAssertFalse(a.config.isRanked)
        XCTAssertTrue((3...8).contains(a.cpuLevel))
        XCTAssertTrue(a.config.hasSpecialRules || a.config.isSplittingEnabled || a.config.handCount == 3)
    }

    func testDailyChallengeRewardOncePerDay() async {
        let stats = makeStats()
        let challenge = stats.todaysChallenge
        var summary = GameSummary(mode: .vsAI, outcome: .win, turnCount: 15, config: challenge.config)
        var r = stats.record(summary)
        XCTAssertTrue(r.dailyChallengeCleared)
        XCTAssertTrue(stats.hasClearedTodaysChallenge)
        XCTAssertEqual(stats.dailyChallengeClears, 1)
        let firstXP = r.xpGained
        r = stats.record(summary)
        XCTAssertFalse(r.dailyChallengeCleared, "同じ日の2回目はボーナスなし")
        XCTAssertEqual(r.xpGained, firstXP - DailyChallenge.bonusXP)
        XCTAssertEqual(stats.rankLevel, 1, "デイリーはランクに影響しない")

        now = calendar.date(byAdding: .day, value: 1, to: now)
        summary.config = stats.todaysChallenge.config
        r = stats.record(summary)
        XCTAssertTrue(r.dailyChallengeCleared)
        XCTAssertEqual(stats.dailyChallengeClears, 2)
    }

    func testDailyChallengeAlwaysUsesFairRules() async {
        var titles = Set<String>()
        for offset in 0..<400 {
            let date = calendar.date(byAdding: .day, value: offset, to: now)!
            let challenge = DailyChallenge.forDate(date, calendar: calendar)
            let c = challenge.config
            XCTAssertTrue(c.isOverflowWrapEnabled, "クラシックは使わない")
            XCTAssertFalse(c.isBombEnabled, "爆弾の単独使用は使わない")
            XCTAssertTrue((3...8).contains(challenge.cpuLevel))
            XCTAssertTrue(c.isSplittingEnabled || c.isPoisonEnabled || c.isMirrorEnabled || c.isDoubleTapEnabled || c.handCount == 3,
                          "標準ルールのままの日はない")
            XCTAssertEqual(challenge, DailyChallenge.forDate(date, calendar: calendar), "同じ日は同じ内容")
            titles.insert(challenge.title)
        }
        XCTAssertGreaterThan(titles.count, 10, "日ごとに十分違う内容になる")
    }

    func testDayKeyIgnoresUserCalendar() async {
        for identifier in [Calendar.Identifier.japanese, .buddhist, .gregorian] {
            var userCalendar = Calendar(identifier: identifier)
            userCalendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
            XCTAssertEqual(DailyChallenge.dayKey(for: now, calendar: userCalendar), "2026-10-01", "\(identifier)でも西暦の日付になる")
        }
    }

    func testDailyWinOnlyCountsWithTodaysRules() async {
        let stats = makeStats()
        let yesterday = DailyChallenge.forDayKey("2026-09-30")
        XCTAssertNotEqual(yesterday.config, stats.todaysChallenge.config, "前提: 前日と今日で条件が違う")
        let rewards = stats.record(GameSummary(mode: .vsAI, outcome: .win, turnCount: 15, config: yesterday.config))
        XCTAssertFalse(rewards.dailyChallengeCleared, "前日の条件で遊んだ勝利は今日のクリアにならない")
        XCTAssertFalse(stats.hasClearedTodaysChallenge)
        XCTAssertEqual(rewards.xpGained, PlayerLevel.xpReward(for: GameSummary(mode: .vsAI, outcome: .win, turnCount: 15, config: yesterday.config), rankLevel: 1) - DailyChallenge.bonusXP)
    }

    // MARK: - 実績

    func testAchievementsUnlockOnce() async {
        let stats = makeStats()
        let store = AchievementStore(defaults: defaults, now: { self.now })
        let summary = rankedWin(level: 1, turns: 8, perfect: true)
        stats.record(summary)
        let unlocked = store.evaluate(summary: summary, stats: stats)
        XCTAssertTrue(unlocked.contains(.firstWin))
        XCTAssertTrue(unlocked.contains(.perfectWin))
        XCTAssertTrue(unlocked.contains(.speedWin))
        XCTAssertFalse(unlocked.contains(.streak3))
        XCTAssertEqual(store.pendingToasts, unlocked)

        let again = store.evaluate(summary: summary, stats: stats)
        XCTAssertTrue(again.isEmpty, "一度解除した実績は再解除しない")

        let reloaded = AchievementStore(defaults: defaults, now: { self.now })
        XCTAssertTrue(reloaded.isUnlocked(.firstWin))
        XCTAssertEqual(reloaded.unlockedCount, unlocked.count)
    }

    func testRuleAchievements() async {
        let stats = makeStats()
        let store = AchievementStore(defaults: defaults, now: { self.now })
        var config = GameConfig()
        config.gameMode = .localTwoPlayer
        config.isBombEnabled = true
        let local = GameSummary(mode: .localTwoPlayer, outcome: .completed, turnCount: 10, config: config)
        stats.record(local)
        let unlocked = store.evaluate(summary: local, stats: stats)
        XCTAssertTrue(unlocked.contains(.localDuel))
        XCTAssertFalse(unlocked.contains(.ruleBomb), "勝者が特定できない対戦ではルール実績は付かない")
    }

    // MARK: - リセット

    func testResetClearsEverything() async {
        let stats = makeStats()
        stats.record(rankedWin(level: 1))
        stats.resetAll()
        XCTAssertEqual(stats.wins, 0)
        XCTAssertEqual(stats.rankLevel, 1)
        XCTAssertEqual(stats.xp, 0)
        XCTAssertNil(stats.lastPlayDay)
        let reloaded = makeStats()
        XCTAssertEqual(reloaded.totalGames, 0)
    }

    // MARK: - 中断セッション

    func testSavedGameRoundTrip() async {
        var config = GameConfig()
        config.gameMode = .vsAI
        config.aiLevel = 3
        var state = GameState(config: config)
        state.player1.hands[0].fingerCount = 3
        GameSessionStore.save(state: state, attacksThisTurn: 1, defaults: defaults, now: now)
        let loaded = GameSessionStore.load(defaults: defaults, now: now)
        XCTAssertEqual(loaded?.state, state)
        XCTAssertEqual(loaded?.attacksThisTurn, 1)

        let later = calendar.date(byAdding: .day, value: 4, to: now)!
        XCTAssertNil(GameSessionStore.load(defaults: defaults, now: later), "古い保存は破棄")

        var mp = GameConfig()
        mp.gameMode = .nearby
        GameSessionStore.save(state: GameState(config: mp), attacksThisTurn: 0, defaults: defaults, now: now)
        XCTAssertNil(GameSessionStore.load(defaults: defaults, now: now), "マルチプレイは保存しない")
    }
}
