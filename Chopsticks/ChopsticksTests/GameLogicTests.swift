import XCTest
@testable import Chopsticks

/// ゲームルール（GameState.apply）のテスト。
/// 実プレイとAIシミュレーションの両方がこのロジックを通る。
final class GameLogicTests: XCTestCase {

    // MARK: - Helpers

    private func makeState(
        config: GameConfig = GameConfig(),
        p1Fingers: [Int]? = nil,
        p2Fingers: [Int]? = nil
    ) -> GameState {
        var state = GameState(config: config)
        if let p1Fingers {
            for (i, count) in p1Fingers.enumerated() {
                state.player1.hands[i].fingerCount = count
            }
        }
        if let p2Fingers {
            for (i, count) in p2Fingers.enumerated() {
                state.player2.hands[i].fingerCount = count
            }
        }
        return state
    }

    private func tap(_ state: inout GameState, attacker: Int, target: Int) -> ActionResult {
        let attackerHand = state.currentPlayer.hands[attacker]
        let targetHand = state.opponentPlayer.hands[target]
        return state.apply(.tap(attackerHandId: attackerHand.id, targetHandId: targetHand.id))
    }

    // MARK: - 基本のタップ

    func testTapAddsAttackerFingersToTarget() {
        var state = makeState(p1Fingers: [3, 1], p2Fingers: [1, 1])
        _ = tap(&state, attacker: 0, target: 0)
        XCTAssertEqual(state.player2.hands[0].fingerCount, 4)
        XCTAssertEqual(state.player1.hands[0].fingerCount, 3, "攻撃側は変化しない")
    }

    func testDeadHandCannotAttackOrBeAttacked() {
        var state = makeState(p1Fingers: [0, 2], p2Fingers: [0, 2])
        // 死んだ手で攻撃 → 無効
        let before = state
        _ = tap(&state, attacker: 0, target: 1)
        XCTAssertEqual(state, before, "死んだ手の攻撃は無視される")
        // 死んだ手への攻撃 → 無効
        _ = tap(&state, attacker: 1, target: 0)
        XCTAssertEqual(state, before, "死んだ手への攻撃は無視される")
    }

    // MARK: - オーバーフロー

    func testWrapExactlyFiveKills() {
        var state = makeState(p1Fingers: [2, 1], p2Fingers: [3, 1])
        let result = tap(&state, attacker: 0, target: 0)
        XCTAssertEqual(state.player2.hands[0].fingerCount, 0)
        XCTAssertFalse(state.player2.hands[0].isAlive)
        XCTAssertEqual(result.deadHandIds, [state.player2.hands[0].id])
    }

    func testWrapOverFiveLoops() {
        var state = makeState(p1Fingers: [4, 1], p2Fingers: [3, 1])
        _ = tap(&state, attacker: 0, target: 0)
        XCTAssertEqual(state.player2.hands[0].fingerCount, 2, "3+4=7 → 7-5=2")
        XCTAssertTrue(state.player2.hands[0].isAlive)
    }

    func testClassicFiveOrMoreKills() {
        var config = GameConfig()
        config.isOverflowWrapEnabled = false
        var state = makeState(config: config, p1Fingers: [4, 1], p2Fingers: [3, 1])
        _ = tap(&state, attacker: 0, target: 0)
        XCTAssertEqual(state.player2.hands[0].fingerCount, 0, "クラシック: 5以上で即死亡")
    }

    // MARK: - 毒

    func testPoisonTradeKillsBothHands() {
        var config = GameConfig()
        config.isPoisonEnabled = true
        var state = makeState(config: config, p1Fingers: [1, 2], p2Fingers: [3, 3])
        let result = tap(&state, attacker: 0, target: 0)
        XCTAssertTrue(result.poisonTriggered)
        XCTAssertFalse(state.player2.hands[0].isAlive, "毒で相手の手は即死")
        XCTAssertFalse(state.player1.hands[0].isAlive, "毒を使った手も死ぬ（相討ち）")
    }

    func testPoisonRequiresExactlyOneFinger() {
        var config = GameConfig()
        config.isPoisonEnabled = true
        var state = makeState(config: config, p1Fingers: [2, 1], p2Fingers: [1, 1])
        let result = tap(&state, attacker: 0, target: 0)
        XCTAssertFalse(result.poisonTriggered)
        XCTAssertEqual(state.player2.hands[0].fingerCount, 3, "2本攻撃は通常の加算")
    }

    // MARK: - ミラー

    func testMirrorAddsToAttackerToo() {
        var config = GameConfig()
        config.isMirrorEnabled = true
        var state = makeState(config: config, p1Fingers: [2, 1], p2Fingers: [1, 1])
        _ = tap(&state, attacker: 0, target: 0)
        XCTAssertEqual(state.player2.hands[0].fingerCount, 3)
        XCTAssertEqual(state.player1.hands[0].fingerCount, 4, "ミラーで攻撃側にも加算")
    }

    func testMirrorSelfKillUnderClassicRule() {
        var config = GameConfig()
        config.isMirrorEnabled = true
        config.isOverflowWrapEnabled = false
        var state = makeState(config: config, p1Fingers: [3, 1], p2Fingers: [1, 1])
        let result = tap(&state, attacker: 0, target: 0)
        XCTAssertEqual(state.player2.hands[0].fingerCount, 4, "1+3=4で相手は生存")
        XCTAssertFalse(state.player1.hands[0].isAlive, "自分は3+3=6≥5で死亡")
        XCTAssertTrue(result.deadHandIds.contains(state.player1.hands[0].id))
    }

    // MARK: - 爆弾

    func testBombExplodesAtExactlyFour() {
        var config = GameConfig()
        config.isBombEnabled = true
        var state = makeState(config: config, p1Fingers: [1, 1], p2Fingers: [3, 1])
        let result = tap(&state, attacker: 0, target: 0)
        // 3+1=4 → 爆発して死亡、他の全ての手に1ダメージ（4になる手はないので連鎖なし）
        XCTAssertTrue(result.bombTriggered)
        XCTAssertFalse(state.player2.hands[0].isAlive)
        XCTAssertEqual(state.player1.hands[0].fingerCount, 2, "攻撃した手も爆風で+1")
        XCTAssertEqual(state.player1.hands[1].fingerCount, 2)
        XCTAssertEqual(state.player2.hands[1].fingerCount, 2)
    }

    func testBombChainReactionWipesBoard() {
        var config = GameConfig()
        config.isBombEnabled = true
        // p1=[4,1], p2=[3,1]の状態でタップすると:
        // p1h0(4)爆発 → 全手+1 → p2h0が4になり爆発 → p2h1が4になり爆発
        // → p1h1が4になり爆発 → 全滅の4連鎖
        var state = makeState(config: config, p1Fingers: [4, 1], p2Fingers: [3, 1])
        let result = tap(&state, attacker: 1, target: 1) // p2h1: 1+1=2
        XCTAssertTrue(result.bombTriggered)
        XCTAssertTrue(state.player1.isDefeated, "連鎖で全滅")
        XCTAssertTrue(state.player2.isDefeated, "連鎖で全滅")
        XCTAssertEqual(result.deadHandIds.count, 4)
    }

    // MARK: - 分割

    func testSplitRedistributesFingers() {
        var config = GameConfig()
        config.isSplittingEnabled = true
        var state = makeState(config: config, p1Fingers: [3, 1], p2Fingers: [1, 1])
        _ = state.apply(.split(newDistribution: [2, 2]))
        XCTAssertEqual(state.player1.hands.map(\.fingerCount), [2, 2])
    }

    func testSplitRejectsRearrangementOnly() {
        let player = Player(name: "P", handCount: 2)
        var p = player
        p.hands[0].fingerCount = 3
        p.hands[1].fingerCount = 1
        XCTAssertFalse(p.isValidSplit(newDistribution: [1, 3], allowRevival: false),
                       "並べ替えだけの分割は不可")
        XCTAssertTrue(p.isValidSplit(newDistribution: [2, 2], allowRevival: false))
    }

    func testSplitRejectsWrongTotalAndRange() {
        var p = Player(name: "P", handCount: 2)
        p.hands[0].fingerCount = 3
        p.hands[1].fingerCount = 2
        XCTAssertFalse(p.isValidSplit(newDistribution: [3, 3], allowRevival: false), "合計が違う")
        XCTAssertFalse(p.isValidSplit(newDistribution: [5, 0], allowRevival: false), "5本は不可")
        XCTAssertFalse(p.isValidSplit(newDistribution: [-1, 6], allowRevival: false))
    }

    func testSplitRevivalRule() {
        var p = Player(name: "P", handCount: 2)
        p.hands[0].fingerCount = 0
        p.hands[1].fingerCount = 4
        XCTAssertFalse(p.isValidSplit(newDistribution: [2, 2], allowRevival: false),
                       "復活OFFでは死んだ手に割り当て不可")
        XCTAssertTrue(p.isValidSplit(newDistribution: [2, 2], allowRevival: true),
                      "復活ONなら死んだ手を復活できる")
    }

    // MARK: - 勝敗

    func testDefeatDetection() {
        var state = makeState(p1Fingers: [1, 1], p2Fingers: [0, 1])
        XCTAssertFalse(state.player2.isDefeated)
        state.player2.hands[1].fingerCount = 0
        XCTAssertTrue(state.player2.isDefeated)
    }

    func testSwitchTurnAlternatesAndCounts() {
        var state = makeState()
        let first = state.currentPlayerId
        state.switchTurn()
        XCTAssertNotEqual(state.currentPlayerId, first)
        XCTAssertEqual(state.turnCount, 1)
        state.switchTurn()
        XCTAssertEqual(state.currentPlayerId, first)
        XCTAssertEqual(state.turnCount, 2)
    }

    // MARK: - Codable

    func testGameStateCodableRoundTrip() throws {
        var config = GameConfig()
        config.isPoisonEnabled = true
        config.gameMode = .online
        var state = GameState(config: config)
        state.player1.hands[0].fingerCount = 3
        state.phase = .gameOver(winnerId: state.player2.id)

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(decoded, state)
    }

    func testGameConfigDecodesLegacyJSONWithoutNewFields() throws {
        // isDailyChallenge導入前のJSON（旧バージョンの保存データ/通信相手）が読めること
        let legacy = """
        {"isSplittingEnabled":true,"isOverflowWrapEnabled":true,\
        "isDeadHandRevivalEnabled":false,"handCount":2,"gameMode":"vsAI",\
        "aiDifficulty":"hard","isPoisonEnabled":true,"isBombEnabled":false,\
        "isMirrorEnabled":false,"isDoubleTapEnabled":false}
        """
        let config = try JSONDecoder().decode(GameConfig.self, from: Data(legacy.utf8))
        XCTAssertTrue(config.isSplittingEnabled)
        XCTAssertTrue(config.isPoisonEnabled)
        XCTAssertEqual(config.gameMode, .vsAI)
        XCTAssertEqual(config.aiDifficulty, .hard)
        XCTAssertNil(config.aiLevel)
        XCTAssertFalse(config.isDailyChallenge, "欠落キーはデフォルト値")
    }

    // MARK: - リプレイシミュレータ

    func testReplaySimulatorHandlesDoubleTapTurnFlow() {
        var config = GameConfig()
        config.isDoubleTapEnabled = true
        let initial = GameState(config: config)
        let firstPlayerId = initial.currentPlayerId
        let attacker = initial.currentPlayer.hands[0]
        let target0 = initial.opponentPlayer.hands[0]
        let target1 = initial.opponentPlayer.hands[1]

        let replay = Replay(
            initialState: initial,
            actions: [
                .tap(attackerHandId: attacker.id, targetHandId: target0.id),
                .tap(attackerHandId: attacker.id, targetHandId: target1.id),
            ],
            savedAt: .now
        )
        let snapshots = ReplaySimulator.snapshots(for: replay)
        XCTAssertEqual(snapshots.count, 3)
        XCTAssertEqual(snapshots[1].currentPlayerId, firstPlayerId,
                       "ダブルタップ1回目の後は手番継続")
        XCTAssertNotEqual(snapshots[2].currentPlayerId, firstPlayerId,
                          "2回目の攻撃で手番交代")
    }

    // MARK: - 今日の挑戦

    func testDailyChallengeConfigIsDeterministicPerDay() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let first = DailyChallenge.config(for: date)
        let second = DailyChallenge.config(for: date)
        XCTAssertEqual(first, second, "同じ日は必ず同じルール")
        XCTAssertTrue(first.isDailyChallenge)
        XCTAssertEqual(first.gameMode, .vsAI)
        XCTAssertNil(first.aiLevel)
        XCTAssertTrue(
            first.isSplittingEnabled || first.isPoisonEnabled || first.isBombEnabled
                || first.isMirrorEnabled || first.isDoubleTapEnabled,
            "少なくとも1つは特殊ルールが入る"
        )
    }

    func testMultiplayerMessageCodableRoundTrip() throws {
        let state = GameState()
        let action = GameAction.tap(
            attackerHandId: state.player1.hands[0].id,
            targetHandId: state.player2.hands[0].id
        )
        let messages: [MultiplayerMessage] = [
            .gameStart(state),
            .action(action),
            .action(.split(newDistribution: [2, 1])),
            .stateSync(state),
            .rematchRequest,
            .rematchAccepted,
            .disconnect,
        ]
        for message in messages {
            let data = try XCTUnwrap(message.encoded())
            XCTAssertNotNil(MultiplayerMessage.decoded(from: data))
        }
    }
}
