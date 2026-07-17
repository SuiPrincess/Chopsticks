import XCTest
@testable import Chopsticks

final class AIEngineTests: XCTestCase {

    /// テストは短い持ち時間で十分（深さ数手で正解が出る局面のみ扱う）
    private let testThinkTime: Duration = .milliseconds(50)

    // MARK: - 行動生成

    func testGeneratesAllTapCombinations() {
        let state = GameState()
        let actions = AIEngine.generateAllActions(state: state)
        // 2×2 = 4通りのタップ、分割OFF
        XCTAssertEqual(actions.count, 4)
    }

    func testGeneratesSplitsWhenEnabled() {
        var config = GameConfig()
        config.isSplittingEnabled = true
        var state = GameState(config: config)
        state.player1.hands[0].fingerCount = 3
        state.player1.hands[1].fingerCount = 1
        let actions = AIEngine.generateAllActions(state: state)
        let splits = actions.filter {
            if case .split = $0 { return true }
            return false
        }
        // 合計4を2手に分配: (0,4)(2,2)(4,0) ※(1,3)(3,1)は並べ替えのみで不可
        XCTAssertEqual(splits.count, 3)
    }

    func testDeadHandsGenerateNoActions() {
        var state = GameState()
        state.player1.hands[0].fingerCount = 0
        state.player2.hands[1].fingerCount = 0
        let actions = AIEngine.generateAllActions(state: state)
        XCTAssertEqual(actions.count, 1, "生きてる手1×1の組み合わせのみ")
    }

    // MARK: - ムーブオーダリング

    func testKillTapOrderedFirst() {
        var state = GameState()
        state.player1.hands[0].fingerCount = 4
        state.player2.hands[0].fingerCount = 1
        let ordered = AIEngine.orderedActions(state: state)
        guard case .tap(let attackerId, let targetId) = ordered.first else {
            return XCTFail("先頭がタップでない")
        }
        XCTAssertEqual(attackerId, state.player1.hands[0].id, "4本の手が1本の手を叩けば5で即キル")
        XCTAssertEqual(targetId, state.player2.hands[0].id)
    }

    // MARK: - 探索

    func testTakesImmediateWin() {
        // AI(P2)の手に4本、P1は1本の手が1つだけ → 4+1=5 で即勝ち
        var state = GameState()
        state.player2.hands[0].fingerCount = 4
        state.player1.hands[0].fingerCount = 1
        state.player1.hands[1].fingerCount = 0
        state.currentPlayerId = state.player2.id

        let actions = AIEngine.orderedActions(state: state)
        let action = AIEngine.chooseBestAction(
            state: state, actions: actions, attacksUsed: 0,
            maxDepth: 4, thinkTime: testThinkTime
        )
        var next = state
        next.apply(action)
        XCTAssertTrue(next.player1.isDefeated, "1手勝ちを逃さない")
    }

    func testAvoidsImmediateLoss() {
        // AI(P2)は手が1つ(2本)。P1は(3本,1本)。
        // AIが1本の手を叩いて2にすると、次にP1の3本の手で 2+3=5 で殺される。
        // 3本の手を叩けば 3+2=5 で即キルでき、その後は負けない。
        var state = GameState()
        state.player2.hands[0].fingerCount = 2
        state.player2.hands[1].fingerCount = 0
        state.player1.hands[0].fingerCount = 3
        state.player1.hands[1].fingerCount = 1
        state.currentPlayerId = state.player2.id

        let actions = AIEngine.orderedActions(state: state)
        let action = AIEngine.chooseBestAction(
            state: state, actions: actions, attacksUsed: 0,
            maxDepth: 6, thinkTime: testThinkTime
        )
        guard case .tap(_, let targetId) = action else {
            return XCTFail("タップを選ぶはず")
        }
        XCTAssertEqual(targetId, state.player1.hands[0].id, "3本の手を消さないと次で負ける")
    }

    func testChoosesActionForEveryRuleCombination() {
        // どのルールの組み合わせでもクラッシュせず妥当な行動を返す
        var configs: [GameConfig] = []
        for poison in [false, true] {
            for bomb in [false, true] {
                for mirror in [false, true] {
                    var config = GameConfig()
                    config.isPoisonEnabled = poison
                    config.isBombEnabled = bomb
                    config.isMirrorEnabled = mirror
                    config.isSplittingEnabled = poison != bomb
                    config.isDoubleTapEnabled = mirror
                    configs.append(config)
                }
            }
        }
        for config in configs {
            var state = GameState(config: config)
            state.player1.hands[0].fingerCount = 2
            state.player2.hands[1].fingerCount = 3
            let action = AIEngine.chooseAction(state: state, difficulty: .hard)
            XCTAssertNotNil(action)
            let valid = AIEngine.generateAllActions(state: state)
            XCTAssertTrue(valid.contains(action!), "生成集合に含まれる行動を返す")
        }
    }

    func testRankedLevelsReturnValidActions() {
        for level in 1...10 {
            let state = GameState()
            let action = AIEngine.chooseAction(state: state, level: level)
            XCTAssertNotNil(action, "Lv.\(level)")
        }
    }

    func testRespondsWithinTimeBudget() {
        // 分岐の多い盤面でも持ち時間+マージン内に返る
        var config = GameConfig()
        config.isSplittingEnabled = true
        config.handCount = 3
        config.isDoubleTapEnabled = true
        var state = GameState(config: config)
        for i in 0..<3 {
            state.player1.hands[i].fingerCount = i + 1
            state.player2.hands[i].fingerCount = i + 1
        }
        let clock = ContinuousClock()
        let start = clock.now
        _ = AIEngine.chooseAction(state: state, difficulty: .oni)
        let elapsed = clock.now - start
        XCTAssertLessThan(elapsed, .seconds(2), "鬼でも応答は速い")
    }

    // MARK: - 評価関数

    func testEvaluationPrefersMoreAliveHands() {
        var state = GameState()
        let before = AIEngine.evaluateState(state, for: state.player1.id)
        state.player2.hands[0].fingerCount = 0
        let after = AIEngine.evaluateState(state, for: state.player1.id)
        XCTAssertGreaterThan(after, before, "相手の手が死ぬほど評価が上がる")
    }

    func testEvaluationPenalizesOwnDeadHands() {
        var state = GameState()
        let before = AIEngine.evaluateState(state, for: state.player1.id)
        state.player1.hands[0].fingerCount = 0
        let after = AIEngine.evaluateState(state, for: state.player1.id)
        XCTAssertLessThan(after, before, "自分の手が死ぬほど評価が下がる")
    }
}
