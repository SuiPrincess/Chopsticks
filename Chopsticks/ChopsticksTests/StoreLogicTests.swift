import XCTest
@testable import Chopsticks

/// GameStats / SettingsStore / GameSessionStore / ThemeStore のロジックを
/// 隔離したUserDefaultsスイート＋固定日付で検証する。
/// （シングルトンではなく専用インスタンスを使うため実データを汚さない）
@MainActor
final class StoreLogicTests: XCTestCase {

    private var defaults: UserDefaults!
    private static let suiteName = "com.suiprincess.chopsticks.tests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: Self.suiteName)
        defaults.removePersistentDomain(forName: Self.suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: Self.suiteName)
        super.tearDown()
    }

    /// 決定的な基準日（2026-01-15 12:00 UTC相当）＋日数オフセット
    private func day(_ offset: Int, hour: Int = 12) -> Date {
        let base = Date(timeIntervalSince1970: 1_768_478_400)
        let start = Calendar.current.startOfDay(for: base)
        return Calendar.current.date(
            byAdding: DateComponents(day: offset, hour: hour), to: start
        )!
    }

    // MARK: - GameStats: 連続プレイ日数

    func testDailyStreakGrowsOnConsecutiveDays() {
        let stats = GameStats(defaults: defaults)
        stats.recordDailyPlay(on: day(0))
        XCTAssertEqual(stats.dailyStreak, 1, "初日は1")
        stats.recordDailyPlay(on: day(0, hour: 20))
        XCTAssertEqual(stats.dailyStreak, 1, "同日2回目は変化なし")
        stats.recordDailyPlay(on: day(1))
        XCTAssertEqual(stats.dailyStreak, 2, "翌日で+1")
        stats.recordDailyPlay(on: day(2, hour: 1))
        XCTAssertEqual(stats.dailyStreak, 3, "日付が変わった直後でも+1")
    }

    func testDailyStreakResetsAfterGap() {
        let stats = GameStats(defaults: defaults)
        stats.recordDailyPlay(on: day(0))
        stats.recordDailyPlay(on: day(1))
        XCTAssertEqual(stats.dailyStreak, 2)
        stats.recordDailyPlay(on: day(3))
        XCTAssertEqual(stats.dailyStreak, 1, "1日空いたら1にリセット")
    }

    func testStatsPersistAcrossInstances() {
        let stats = GameStats(defaults: defaults)
        stats.recordGame(playerWon: true)
        stats.recordGame(playerWon: true)
        stats.recordGame(playerWon: false)
        _ = stats.registerRankedWin()

        let reloaded = GameStats(defaults: defaults)
        XCTAssertEqual(reloaded.wins, 2)
        XCTAssertEqual(reloaded.losses, 1)
        XCTAssertEqual(reloaded.currentStreak, 0)
        XCTAssertEqual(reloaded.bestStreak, 2)
        XCTAssertEqual(reloaded.rankLevel, 2)
    }

    // MARK: - GameStats: 連勝と記録更新

    func testBestStreakAndNewRecordFlag() {
        let stats = GameStats(defaults: defaults)
        stats.recordGame(playerWon: true)
        XCTAssertFalse(stats.didSetNewRecord, "初勝利は記録更新と騒がない")
        stats.recordGame(playerWon: true)
        XCTAssertTrue(stats.didSetNewRecord, "2連勝でベスト更新")
        stats.recordGame(playerWon: false)
        XCTAssertFalse(stats.didSetNewRecord)
        stats.recordGame(playerWon: true)
        XCTAssertFalse(stats.didSetNewRecord, "ベスト2に対して連勝1では更新なし")
    }

    func testRankLevelCapsAtMax() {
        let stats = GameStats(defaults: defaults)
        for _ in 1..<GameStats.maxRankLevel {
            XCTAssertTrue(stats.registerRankedWin())
        }
        XCTAssertEqual(stats.rankLevel, GameStats.maxRankLevel)
        XCTAssertFalse(stats.registerRankedWin(), "上限では上がらない")
        XCTAssertEqual(stats.rankLevel, GameStats.maxRankLevel)
    }

    // MARK: - GameStats: 今日の挑戦

    func testDailyChallengeCountAcrossDays() {
        let stats = GameStats(defaults: defaults)
        stats.markDailyChallengeCleared(on: day(0))
        stats.markDailyChallengeCleared(on: day(0, hour: 22))
        XCTAssertEqual(stats.dailyChallengeClearCount, 1, "同日は1回だけカウント")
        stats.markDailyChallengeCleared(on: day(1))
        XCTAssertEqual(stats.dailyChallengeClearCount, 2)
        XCTAssertTrue(stats.isDailyChallengeCleared(asOf: day(1)))
        XCTAssertFalse(stats.isDailyChallengeCleared(asOf: day(2)), "翌日は未クリア扱い")
    }

    func testResetClearsEverything() {
        let stats = GameStats(defaults: defaults)
        stats.recordGame(playerWon: true)
        stats.recordDailyPlay(on: day(0))
        stats.markDailyChallengeCleared(on: day(0))
        _ = stats.registerRankedWin()
        stats.reset()

        XCTAssertEqual(stats.wins, 0)
        XCTAssertEqual(stats.dailyStreak, 0)
        XCTAssertEqual(stats.rankLevel, 1)
        XCTAssertEqual(stats.dailyChallengeClearCount, 0)
        XCTAssertFalse(stats.isDailyChallengeCleared(asOf: day(0)))

        let reloaded = GameStats(defaults: defaults)
        XCTAssertEqual(reloaded.wins, 0)
        XCTAssertEqual(reloaded.dailyChallengeClearCount, 0)
    }

    // MARK: - SettingsStore: ヒントクォータの日跨ぎ

    func testHintQuotaResetsNextDay() {
        let settings = SettingsStore(defaults: defaults)
        for _ in 0..<SettingsStore.freeHintsPerDay {
            XCTAssertTrue(settings.consumeHint(on: day(0)))
        }
        XCTAssertFalse(settings.consumeHint(on: day(0)), "当日は上限")
        XCTAssertEqual(settings.hintsUsed(asOf: day(0)), SettingsStore.freeHintsPerDay)

        XCTAssertEqual(settings.hintsUsed(asOf: day(1)), 0, "翌日は自動リセット")
        XCTAssertTrue(settings.consumeHint(on: day(1)))
    }

    func testSettingsTogglePersistence() {
        let settings = SettingsStore(defaults: defaults)
        XCTAssertTrue(settings.isSoundEnabled, "デフォルトON")
        XCTAssertFalse(settings.isDailyReminderEnabled, "リマインダーはデフォルトOFF")
        settings.isSoundEnabled = false
        settings.isDailyReminderEnabled = true

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertFalse(reloaded.isSoundEnabled)
        XCTAssertTrue(reloaded.isDailyReminderEnabled)
    }

    // MARK: - GameSessionStore

    func testSessionStoreSaveAndReload() {
        let store = GameSessionStore(defaults: defaults)
        var state = GameState(config: GameConfig())
        XCTAssertNil(store.savedGame)

        store.save(state: state, attacksThisTurn: 0)
        XCTAssertNil(store.savedGame, "0手のゲームは保存しない")

        state.switchTurn()
        store.save(state: state, attacksThisTurn: 0)
        XCTAssertNotNil(store.savedGame)

        let reloaded = GameSessionStore(defaults: defaults)
        XCTAssertEqual(reloaded.savedGame?.state, state, "再起動相当でも復元できる")

        store.clear()
        XCTAssertNil(GameSessionStore(defaults: defaults).savedGame)
    }

    func testSessionStoreRejectsMultiplayer() {
        let store = GameSessionStore(defaults: defaults)
        var config = GameConfig()
        config.gameMode = .nearby
        var state = GameState(config: config)
        state.switchTurn()
        store.save(state: state, attacksThisTurn: 0)
        XCTAssertNil(store.savedGame, "マルチプレイは保存しない")
    }

    // MARK: - 鬼勝利数（報酬テーマ「オニ」の解放条件）

    func testOniWinsPersistAndReset() {
        let stats = GameStats(defaults: defaults)
        XCTAssertEqual(stats.oniWins, 0)
        stats.recordOniWin()
        stats.recordOniWin()
        XCTAssertEqual(GameStats(defaults: defaults).oniWins, 2, "鬼勝利数は永続化される")
        stats.reset()
        XCTAssertEqual(stats.oniWins, 0)
        XCTAssertEqual(GameStats(defaults: defaults).oniWins, 0, "リセットで消える")
    }

    // MARK: - 今週の試練（週1回クリア記録）

    func testWeeklyChallengeCountsOncePerWeek() {
        // day(0)=2026-01-15(木)。day(3)=日曜で同じISO週、day(4)=月曜で翌週
        let stats = GameStats(defaults: defaults)
        XCTAssertFalse(stats.isWeeklyChallengeCleared(asOf: day(0)))
        stats.markWeeklyChallengeCleared(on: day(0))
        XCTAssertEqual(stats.weeklyChallengeClearCount, 1)
        XCTAssertTrue(stats.isWeeklyChallengeCleared(asOf: day(3)), "同じ週の日曜はクリア済み扱い")
        stats.markWeeklyChallengeCleared(on: day(2))
        XCTAssertEqual(stats.weeklyChallengeClearCount, 1, "同じ週の2回目はカウントしない")
        XCTAssertFalse(stats.isWeeklyChallengeCleared(asOf: day(4)), "翌週の月曜は未クリアに戻る")
        stats.markWeeklyChallengeCleared(on: day(4))
        XCTAssertEqual(stats.weeklyChallengeClearCount, 2, "翌週のクリアはカウントされる")
        XCTAssertEqual(GameStats(defaults: defaults).weeklyChallengeClearCount, 2, "永続化される")
    }

    // MARK: - ThemeStore

    func testThemeStorePersistsSelection() {
        let store = ThemeStore(defaults: defaults)
        XCTAssertEqual(store.current.id, Theme.neon.id, "デフォルトはネオン")
        store.select(.sunset, isPremiumPurchased: true, challengeClears: 0, oniWins: 0)

        let reloaded = ThemeStore(defaults: defaults)
        XCTAssertEqual(reloaded.current.id, Theme.sunset.id)
    }

    func testUnknownStoredThemeFallsBackToNeon() {
        defaults.set("deleted-theme-id", forKey: "theme.selected")
        let store = ThemeStore(defaults: defaults)
        XCTAssertEqual(store.current.id, Theme.neon.id, "未知のIDはネオンにフォールバック")
    }
}
