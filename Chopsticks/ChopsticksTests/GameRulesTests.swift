import XCTest
@testable import Chopsticks

/// ルール適用（GameState.apply）のテスト。実プレイとAIシミュレーションの両方がここを通る。
final class GameRulesTests: XCTestCase {

    private func makeState(_ configure: (inout GameConfig) -> Void = { _ in }) -> GameState {
        var config = GameConfig()
        config.gameMode = .localTwoPlayer
        configure(&config)
        return GameState(config: config)
    }

    private func set(_ state: inout GameState, p1: [Int], p2: [Int]) {
        for (i, c) in p1.enumerated() { state.player1.hands[i].fingerCount = c }
        for (i, c) in p2.enumerated() { state.player2.hands[i].fingerCount = c }
    }

    private func tap(_ state: inout GameState, attacker: Int, target: Int) -> ActionResult {
        let a = state.currentPlayer.hands[attacker].id
        let t = state.opponentPlayer.hands[target].id
        return state.apply(.tap(attackerHandId: a, targetHandId: t))
    }

    // MARK: - 基本

    func testTapAddsAttackerFingers() {
        var s = makeState()
        set(&s, p1: [3, 1], p2: [1, 2])
        _ = tap(&s, attacker: 0, target: 1)
        XCTAssertEqual(s.player2.hands.map(\.fingerCount), [1, 0], "1+3=4ではなく... 2+3=5で死亡")
    }

    func testOverflowWrapsAboveFive() {
        var s = makeState()
        set(&s, p1: [4, 1], p2: [3, 1])
        _ = tap(&s, attacker: 0, target: 0)
        XCTAssertEqual(s.player2.hands[0].fingerCount, 2, "3+4=7 → 7-5=2")
    }

    func testExactlyFiveKills() {
        var s = makeState()
        set(&s, p1: [2, 1], p2: [3, 1])
        let r = tap(&s, attacker: 0, target: 0)
        XCTAssertEqual(s.player2.hands[0].fingerCount, 0)
        XCTAssertEqual(r.deadHandIds, [s.player2.hands[0].id])
    }

    func testClassicRuleKillsAtFiveOrMore() {
        var s = makeState { $0.isOverflowWrapEnabled = false }
        set(&s, p1: [4, 1], p2: [3, 1])
        _ = tap(&s, attacker: 0, target: 0)
        XCTAssertEqual(s.player2.hands[0].fingerCount, 0)
    }

    func testCannotAttackWithDeadHandOrDeadTarget() {
        var s = makeState()
        set(&s, p1: [0, 2], p2: [1, 0])
        _ = tap(&s, attacker: 0, target: 0)
        XCTAssertEqual(s.player2.hands[0].fingerCount, 1, "死んだ手では攻撃できない")
        _ = tap(&s, attacker: 1, target: 1)
        XCTAssertEqual(s.player2.hands[1].fingerCount, 0, "死んだ手は攻撃できない")
    }

    // MARK: - 分割

    func testSplitCannotKillOwnHand() {
        let player = Player(name: "p", handCount: 2)  // [1, 1]
        XCTAssertFalse(player.isValidSplit(newDistribution: [2, 0], allowRevival: false))
        XCTAssertFalse(player.isValidSplit(newDistribution: [2, 0], allowRevival: true))
        XCTAssertFalse(player.hasValidSplit(allowRevival: false), "[1,1]からは並べ替えしかできない")
    }

    func testSplitRedistributes() {
        var player = Player(name: "p", handCount: 2)
        player.hands[0].fingerCount = 3
        player.hands[1].fingerCount = 1
        XCTAssertTrue(player.isValidSplit(newDistribution: [2, 2], allowRevival: false))
        XCTAssertFalse(player.isValidSplit(newDistribution: [1, 3], allowRevival: false), "並べ替えだけは不可")
        XCTAssertFalse(player.isValidSplit(newDistribution: [4, 0], allowRevival: false))
        XCTAssertFalse(player.isValidSplit(newDistribution: [5, -1], allowRevival: false))
    }

    func testRevivalRequiresRule() {
        var player = Player(name: "p", handCount: 2)
        player.hands[0].fingerCount = 2
        player.hands[1].fingerCount = 0
        XCTAssertFalse(player.isValidSplit(newDistribution: [1, 1], allowRevival: false))
        XCTAssertTrue(player.isValidSplit(newDistribution: [1, 1], allowRevival: true))
    }

    func testSplitIsIgnoredWhenRuleOff() {
        var s = makeState()
        set(&s, p1: [3, 1], p2: [1, 1])
        s.apply(.split(newDistribution: [2, 2]))
        XCTAssertEqual(s.player1.hands.map(\.fingerCount), [3, 1])
    }

    func testAIGeneratesOnlyValidSplits() {
        var s = makeState { $0.isSplittingEnabled = true }
        set(&s, p1: [3, 1], p2: [1, 1])
        let splits = AIEngine.generateAllActions(state: s).compactMap { action -> [Int]? in
            if case .split(let d) = action { return d }
            return nil
        }
        XCTAssertEqual(Set(splits.map { $0 }), Set([[2, 2]]))
    }

    // MARK: - 毒

    func testPoisonKillsBigHandAndSelf() {
        var s = makeState { $0.isPoisonEnabled = true }
        set(&s, p1: [1, 2], p2: [3, 1])
        let r = tap(&s, attacker: 0, target: 0)
        XCTAssertTrue(r.poisonTriggered)
        XCTAssertEqual(s.player2.hands[0].fingerCount, 0)
        XCTAssertEqual(s.player1.hands[0].fingerCount, 0, "毒を使った手も死ぬ")
    }

    func testPoisonDoesNotTriggerOnOneFingerTarget() {
        var s = makeState { $0.isPoisonEnabled = true }
        set(&s, p1: [1, 1], p2: [1, 1])
        let r = tap(&s, attacker: 0, target: 0)
        XCTAssertFalse(r.poisonTriggered, "開幕の1本同士は通常の攻撃")
        XCTAssertEqual(s.player2.hands[0].fingerCount, 2)
        XCTAssertEqual(s.player1.hands[0].fingerCount, 1)
    }

    func testPoisonOpeningIsNotForcedMutualKill() {
        var s = makeState { $0.isPoisonEnabled = true }
        let actions = AIEngine.generateAllActions(state: s)
        XCTAssertFalse(actions.isEmpty)
        for action in actions {
            var next = s
            let r = next.apply(action)
            XCTAssertFalse(r.poisonTriggered)
        }
    }

    // MARK: - ミラー

    func testMirrorAddsToAttacker() {
        var s = makeState { $0.isMirrorEnabled = true }
        set(&s, p1: [2, 1], p2: [1, 1])
        _ = tap(&s, attacker: 0, target: 0)
        XCTAssertEqual(s.player2.hands[0].fingerCount, 3)
        XCTAssertEqual(s.player1.hands[0].fingerCount, 4)
    }

    func testMirrorCanKillAttacker() {
        var s = makeState { $0.isMirrorEnabled = true }
        set(&s, p1: [3, 1], p2: [1, 1])
        let r = tap(&s, attacker: 0, target: 0)
        XCTAssertEqual(s.player1.hands[0].fingerCount, 1, "3+3=6 → 1")
        XCTAssertFalse(r.deadHandIds.contains(s.player1.hands[0].id))
        set(&s, p1: [4, 1], p2: [1, 1])
        s.currentPlayerId = s.player1.id
        let r2 = tap(&s, attacker: 0, target: 0)
        XCTAssertEqual(s.player2.hands[0].fingerCount, 0, "1+4=5")
        XCTAssertEqual(s.player1.hands[0].fingerCount, 3, "4+4=8 → 3")
        XCTAssertEqual(r2.deadHandIds.count, 1)
    }

    // MARK: - 爆弾

    func testBombExplodesAtFourAndDamagesOthers() {
        var s = makeState { $0.isBombEnabled = true }
        set(&s, p1: [1, 2], p2: [3, 1])
        let r = tap(&s, attacker: 0, target: 0)  // 3+1=4 → 爆発
        XCTAssertTrue(r.bombTriggered)
        XCTAssertEqual(s.player2.hands[0].fingerCount, 0)
        XCTAssertEqual(s.player2.hands[1].fingerCount, 2)
        XCTAssertEqual(s.player1.hands.map(\.fingerCount), [2, 3])
    }

    func testBombChainReaction() {
        var s = makeState { $0.isBombEnabled = true }
        set(&s, p1: [1, 3], p2: [3, 3])
        let r = tap(&s, attacker: 0, target: 0)  // p2[0]=4 → 爆発 → p1[1]=4, p2[1]=4 → 連鎖
        XCTAssertTrue(r.bombTriggered)
        XCTAssertEqual(r.deadHandIds.count, 3)
        XCTAssertTrue(s.player1.hands[1].fingerCount == 0 && s.player2.hands[1].fingerCount == 0)
    }

    func testBombRuleNoExplosionWithoutFour() {
        var s = makeState { $0.isBombEnabled = true }
        set(&s, p1: [1, 1], p2: [1, 1])
        let r = tap(&s, attacker: 0, target: 0)
        XCTAssertFalse(r.bombTriggered)
    }

    // MARK: - サドンデス・脅威判定

    func testSuddenDeathOutcome() {
        var s = makeState()
        set(&s, p1: [1, 1], p2: [0, 3])
        XCTAssertEqual(s.suddenDeathOutcome(), .winner(s.player1.id), "生きている手が多い方")
        set(&s, p1: [1, 3], p2: [2, 1])
        XCTAssertEqual(s.suddenDeathOutcome(), .winner(s.player2.id), "指の合計が少ない方")
        set(&s, p1: [2, 2], p2: [1, 3])
        XCTAssertEqual(s.suddenDeathOutcome(), .draw)
    }

    func testThreatDetectionFollowsRules() {
        var s = makeState()
        set(&s, p1: [4, 1], p2: [1, 2])
        XCTAssertTrue(s.isHandThreatened(s.player1.hands[0].id), "4本は1本の攻撃で死ぬ")
        XCTAssertFalse(s.isHandThreatened(s.player1.hands[1].id), "1本は2本or1本の攻撃では死なない")
        XCTAssertFalse(s.isHandThreatened(s.player2.hands[1].id), "2本は4,1の攻撃では死なない (6→1, 3)")
        set(&s, p1: [3, 1], p2: [2, 2])
        XCTAssertTrue(s.isHandThreatened(s.player1.hands[0].id), "3+2=5")

        var classic = makeState { $0.isOverflowWrapEnabled = false }
        set(&classic, p1: [3, 1], p2: [2, 1])
        XCTAssertTrue(classic.isHandThreatened(classic.player1.hands[0].id), "クラシックでは3+2=5以上で死亡")

        var poison = makeState { $0.isPoisonEnabled = true }
        set(&poison, p1: [2, 2], p2: [1, 1])
        XCTAssertTrue(poison.isHandThreatened(poison.player1.hands[0].id), "毒の脅威")
    }

    // MARK: - Codable 互換

    func testGameConfigDecodesMissingKeysWithDefaults() throws {
        let json = #"{"gameMode":"vsAI","aiLevel":4}"#.data(using: .utf8)!
        let config = try JSONDecoder().decode(GameConfig.self, from: json)
        XCTAssertEqual(config.gameMode, .vsAI)
        XCTAssertEqual(config.aiLevel, 4)
        XCTAssertTrue(config.isOverflowWrapEnabled)
        XCTAssertFalse(config.isDailyChallenge)
        XCTAssertTrue(config.isRanked)
    }

    func testGameStateRoundTrips() throws {
        var s = makeState { $0.isBombEnabled = true }
        set(&s, p1: [2, 3], p2: [1, 0])
        s.phase = .gameOver(winnerId: s.player1.id)
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(decoded, s)
    }
}
