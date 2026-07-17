import XCTest
@testable import Chopsticks

@MainActor
final class GameViewModelTests: XCTestCase {

    // テストはTEST_HOST（アプリ本体）のUserDefaultsを共有するため、
    // 中断セーブを毎回クリアしてテスト間の干渉と実データ汚染を抑える
    override func setUp() {
        super.setUp()
        GameSessionStore.shared.clear()
    }

    override func tearDown() {
        GameSessionStore.shared.clear()
        super.tearDown()
    }

    private func makeLocalGame(configure: ((inout GameConfig) -> Void)? = nil) -> GameViewModel {
        var config = GameConfig()
        config.gameMode = .localTwoPlayer
        configure?(&config)
        return GameViewModel(config: config)
    }

    /// 現在の手番プレイヤーのattacker番の手で、相手のtarget番の手を叩く
    private func performTap(_ viewModel: GameViewModel, attacker: Int, target: Int) {
        let attackerHand = viewModel.currentPlayer.hands[attacker]
        let targetHand = viewModel.opponentPlayer.hands[target]
        viewModel.handleHandTap(attackerHand.id)
        viewModel.handleHandTap(targetHand.id)
    }

    func testFullGameToWin() {
        let viewModel = makeLocalGame()
        // (1,1) vs (1,1) から最短の決着シーケンス
        performTap(viewModel, attacker: 0, target: 0) // P2: (2,1)
        performTap(viewModel, attacker: 0, target: 0) // P1: (3,1)
        performTap(viewModel, attacker: 0, target: 0) // P2: (3+2=5→0,1) BREAK
        XCTAssertFalse(viewModel.isGameOver)
        performTap(viewModel, attacker: 1, target: 0) // P1: (3+1=4,1)
        performTap(viewModel, attacker: 0, target: 1) // P2: (0,1+4=5→0) 全滅
        XCTAssertTrue(viewModel.isGameOver)
        XCTAssertEqual(viewModel.winner?.id, viewModel.state.player1.id)
        XCTAssertTrue(viewModel.isPerfectWin, "P1は手を失っていないのでPERFECT")
    }

    func testDoubleTapGrantsSecondAttack() {
        let viewModel = makeLocalGame { $0.isDoubleTapEnabled = true }
        let firstPlayerId = viewModel.state.currentPlayerId
        performTap(viewModel, attacker: 0, target: 0)
        XCTAssertEqual(viewModel.state.currentPlayerId, firstPlayerId, "1回目の攻撃後も手番継続")
        XCTAssertEqual(viewModel.attacksThisTurn, 1)
        performTap(viewModel, attacker: 0, target: 1)
        XCTAssertNotEqual(viewModel.state.currentPlayerId, firstPlayerId, "2回目の攻撃で手番交代")
        XCTAssertEqual(viewModel.attacksThisTurn, 0)
    }

    func testSplitEndsTurn() {
        let viewModel = makeLocalGame { $0.isSplittingEnabled = true }
        let firstPlayerId = viewModel.state.currentPlayerId
        // (1,1) → (2,0)
        viewModel.performSplit(newDistribution: [2, 0])
        XCTAssertNotEqual(viewModel.state.currentPlayerId, firstPlayerId)
        XCTAssertEqual(viewModel.currentPlayer.id, viewModel.state.player2.id)
    }

    func testInvalidSplitIsRejected() {
        let viewModel = makeLocalGame { $0.isSplittingEnabled = true }
        let before = viewModel.state
        viewModel.performSplit(newDistribution: [1, 1]) // 変化なし → 無効
        XCTAssertEqual(viewModel.state, before)
        viewModel.performSplit(newDistribution: [3, 3]) // 合計が違う → 無効
        XCTAssertEqual(viewModel.state, before)
    }

    func testRematchAlternatesFirstPlayerInLocalGame() {
        let viewModel = makeLocalGame()
        XCTAssertTrue(viewModel.isPlayer1Turn, "初戦はP1先手")
        viewModel.newGame()
        XCTAssertFalse(viewModel.isPlayer1Turn, "再戦はP2先手")
        viewModel.newGame()
        XCTAssertTrue(viewModel.isPlayer1Turn, "先手は交互")
    }

    func testAIGameAlwaysHumanFirst() {
        var config = GameConfig()
        config.gameMode = .vsAI
        config.aiDifficulty = .easy
        let viewModel = GameViewModel(config: config)
        XCTAssertTrue(viewModel.isPlayer1Turn)
        viewModel.newGame()
        XCTAssertTrue(viewModel.isPlayer1Turn, "CPU戦は常に人間が先手")
    }

    func testCannotActAfterGameOver() {
        let viewModel = makeLocalGame()
        performTap(viewModel, attacker: 0, target: 0) // P2: (2,1)
        performTap(viewModel, attacker: 0, target: 0) // P1: (3,1)
        performTap(viewModel, attacker: 0, target: 0) // P2: (0,1)
        performTap(viewModel, attacker: 1, target: 0) // P1: (4,1)
        performTap(viewModel, attacker: 0, target: 1) // P2全滅 → 決着
        XCTAssertTrue(viewModel.isGameOver)
        let endState = viewModel.state
        performTap(viewModel, attacker: 0, target: 0)
        XCTAssertEqual(viewModel.state, endState, "決着後の操作は無効")
    }

    // MARK: - サドンデス（ターン上限）

    func testSuddenDeathDrawAfterTurnLimit() {
        // (2,0)→(1,1)は死んだ手への配分＝復活のため、復活ルールも有効にする
        let viewModel = makeLocalGame {
            $0.isSplittingEnabled = true
            $0.isDeadHandRevivalEnabled = true
        }
        // (1,1)↔(2,0)の分割を交互に繰り返して60ターン膠着させる
        var toWide = true
        var iterations = 0
        while !viewModel.isGameOver && iterations < GameViewModel.turnLimit + 10 {
            let before = viewModel.state.turnCount
            viewModel.performSplit(newDistribution: toWide ? [2, 0] : [1, 1])
            XCTAssertGreaterThan(viewModel.state.turnCount, before, "分割は必ず1ターン進める")
            // 両者が同じ手を打つため、2手ごとに分配パターンを切り替える
            if viewModel.state.turnCount % 2 == 0 {
                toWide.toggle()
            }
            iterations += 1
        }
        XCTAssertEqual(viewModel.state.turnCount, GameViewModel.turnLimit)
        XCTAssertTrue(viewModel.isDraw, "完全同型の膠着はサドンデスで引き分け")
    }

    // MARK: - リプレイ

    func testReplayMatchesActualGameFlow() {
        let viewModel = makeLocalGame()
        performTap(viewModel, attacker: 0, target: 0)
        performTap(viewModel, attacker: 0, target: 0)
        performTap(viewModel, attacker: 0, target: 0)
        performTap(viewModel, attacker: 1, target: 0)
        performTap(viewModel, attacker: 0, target: 1) // 決着（P1勝ち）
        XCTAssertTrue(viewModel.isGameOver)

        guard let replay = viewModel.lastReplay else {
            return XCTFail("決着時にリプレイが記録される")
        }
        XCTAssertEqual(replay.actions.count, 5)

        let snapshots = ReplaySimulator.snapshots(for: replay)
        XCTAssertEqual(snapshots.count, 6, "初期盤面+5手")
        XCTAssertEqual(snapshots.first, replay.initialState)
        XCTAssertEqual(snapshots.last, viewModel.state,
                       "リプレイの最終盤面は実対局と完全一致する")
    }

    func testReplayResetsOnNewGame() {
        let viewModel = makeLocalGame()
        performTap(viewModel, attacker: 0, target: 0)
        performTap(viewModel, attacker: 0, target: 0)
        performTap(viewModel, attacker: 0, target: 0)
        performTap(viewModel, attacker: 1, target: 0)
        performTap(viewModel, attacker: 0, target: 1)
        XCTAssertTrue(viewModel.isGameOver)

        viewModel.newGame()
        XCTAssertNil(viewModel.lastReplay, "新しいゲームの開始でリプレイはリセット")

        // 2局目（再戦はP2先手だが、相対的な手順は対称なので同じ形で決着する）
        performTap(viewModel, attacker: 0, target: 0)
        performTap(viewModel, attacker: 0, target: 0)
        performTap(viewModel, attacker: 0, target: 0)
        performTap(viewModel, attacker: 1, target: 0)
        performTap(viewModel, attacker: 0, target: 1)
        XCTAssertTrue(viewModel.isGameOver)

        guard let replay = viewModel.lastReplay else {
            return XCTFail("2局目の決着でリプレイが記録される")
        }
        XCTAssertEqual(replay.actions.count, 5)
        let snapshots = ReplaySimulator.snapshots(for: replay)
        XCTAssertEqual(snapshots.first, replay.initialState)
        XCTAssertEqual(snapshots.last, viewModel.state,
                       "2局目のリプレイは2局目の盤面から再生される（1局目の盤面が残らない）")
    }

    // MARK: - マネタイズ関連

    func testHintQuotaConsumesAndLimits() {
        // SettingsStore.sharedを使うと実端末の残回数を消費してしまうため、隔離スイートで検証
        let suiteName = "com.suiprincess.chopsticks.tests.hintQuota"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsStore(defaults: defaults)
        XCTAssertEqual(settings.hintsRemainingToday, SettingsStore.freeHintsPerDay)
        for i in 0..<SettingsStore.freeHintsPerDay {
            XCTAssertTrue(settings.consumeHint(), "\(i + 1)回目は成功")
        }
        XCTAssertFalse(settings.consumeHint(), "上限を超えたら失敗")
        XCTAssertEqual(settings.hintsRemainingToday, 0)
    }

    func testThemeSelectionRespectsUnlockRules() {
        let store = ThemeStore.shared
        let original = store.selectedThemeID
        defer { store.selectedThemeID = original }

        store.select(.neon, isPremiumPurchased: false, challengeClears: 0, oniWins: 0)
        XCTAssertEqual(store.selectedThemeID, Theme.neon.id)
        store.select(.sunset, isPremiumPurchased: false, challengeClears: 0, oniWins: 0)
        XCTAssertEqual(store.selectedThemeID, Theme.neon.id, "未購入ではプレミアムテーマを選べない")
        store.select(.sunset, isPremiumPurchased: true, challengeClears: 0, oniWins: 0)
        XCTAssertEqual(store.selectedThemeID, Theme.sunset.id, "プレミアムなら選べる")

        store.select(.midnight, isPremiumPurchased: true, challengeClears: 6, oniWins: 0)
        XCTAssertEqual(store.selectedThemeID, Theme.sunset.id,
                       "報酬テーマはプレミアムでも回数不足なら選べない")
        store.select(.midnight, isPremiumPurchased: false, challengeClears: 7, oniWins: 0)
        XCTAssertEqual(store.selectedThemeID, Theme.midnight.id,
                       "通算7回クリアで課金なしでも解放される")

        store.select(.oni, isPremiumPurchased: true, challengeClears: 99, oniWins: 0)
        XCTAssertEqual(store.selectedThemeID, Theme.midnight.id,
                       "オニは鬼に勝つまでプレミアムでも選べない")
        store.select(.oni, isPremiumPurchased: false, challengeClears: 0, oniWins: 1)
        XCTAssertEqual(store.selectedThemeID, Theme.oni.id,
                       "鬼に1勝すれば課金なしでも解放される")
    }

    func testDailyChallengeClearCountIncrementsOncePerDay() {
        // GameStats.sharedを使うと実端末の戦績をメモリ上で汚染するため、隔離スイートで検証
        let suiteName = "com.suiprincess.chopsticks.tests.dailyClear"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let stats = GameStats(defaults: defaults)
        XCTAssertEqual(stats.dailyChallengeClearCount, 0)
        XCTAssertFalse(stats.isDailyChallengeClearedToday)
        stats.markDailyChallengeCleared()
        XCTAssertEqual(stats.dailyChallengeClearCount, 1)
        XCTAssertTrue(stats.isDailyChallengeClearedToday)
        stats.markDailyChallengeCleared()
        XCTAssertEqual(stats.dailyChallengeClearCount, 1, "同日2回目はカウントしない")
    }

    func testMirrorSuicideGivesOpponentWin() {
        var config = GameConfig()
        config.gameMode = .localTwoPlayer
        config.isMirrorEnabled = true
        config.isOverflowWrapEnabled = false
        let viewModel = GameViewModel(config: config)
        // P1の手を(3,0)にして3本で攻撃 → ミラーで3+3=6≥5 → P1全滅
        var state = viewModel.state
        state.player1.hands[0].fingerCount = 3
        state.player1.hands[1].fingerCount = 0
        // 状態を直接入れ替えられないため、GameStateレベルで検証
        _ = state.apply(.tap(
            attackerHandId: state.player1.hands[0].id,
            targetHandId: state.player2.hands[0].id
        ))
        XCTAssertTrue(state.player1.isDefeated)
        XCTAssertFalse(state.player2.isDefeated)
    }
}
