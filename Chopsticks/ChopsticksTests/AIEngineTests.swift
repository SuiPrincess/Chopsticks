import XCTest
@testable import Chopsticks

final class AIEngineTests: XCTestCase {

    private func makeState(_ configure: (inout GameConfig) -> Void = { _ in }) -> GameState {
        var config = GameConfig()
        config.gameMode = .vsAI
        configure(&config)
        var state = GameState(config: config)
        state.currentPlayerId = state.player2.id  // AIの手番
        return state
    }

    private func set(_ state: inout GameState, human: [Int], ai: [Int]) {
        for (i, c) in human.enumerated() { state.player1.hands[i].fingerCount = c }
        for (i, c) in ai.enumerated() { state.player2.hands[i].fingerCount = c }
    }

    func testGeneratesTapsForAllAlivePairs() {
        var s = makeState()
        set(&s, human: [1, 0], ai: [2, 3])
        let actions = AIEngine.generateAllActions(state: s)
        XCTAssertEqual(actions.count, 2, "AIの2本 × 人間の生きている1本")
    }

    func testHardAITakesImmediateWin() {
        var s = makeState()
        set(&s, human: [0, 2], ai: [3, 1])
        guard case .tap(let attacker, let target)? = AIEngine.chooseAction(state: s, difficulty: .hard) else {
            return XCTFail("tap expected")
        }
        XCTAssertEqual(attacker, s.player2.hands[0].id, "3本で2本を叩けば5で勝ち")
        XCTAssertEqual(target, s.player1.hands[1].id)
    }

    func testLevel10AlsoTakesImmediateWin() {
        var s = makeState()
        set(&s, human: [0, 2], ai: [3, 1])
        for _ in 0..<5 {
            guard case .tap(let attacker, _)? = AIEngine.chooseAction(state: s, level: 10) else {
                return XCTFail("tap expected")
            }
            XCTAssertEqual(attacker, s.player2.hands[0].id)
        }
    }

    func testHardAIAvoidsImmediateLoss() {
        // AI [0,4] vs 人間 [1,3]: 4の手で3を叩くと(7→2)、次に人間の1本で4を叩かれて即負け。
        // 唯一の生き残る手は4で1を叩いて殺す(1+4=5)こと。
        var s = makeState()
        set(&s, human: [1, 3], ai: [0, 4])
        for _ in 0..<5 {
            guard case .tap(let attacker, let target)? = AIEngine.chooseAction(state: s, difficulty: .hard) else {
                return XCTFail("tap expected")
            }
            XCTAssertEqual(attacker, s.player2.hands[1].id)
            XCTAssertEqual(target, s.player1.hands[0].id, "1本の手を先に潰さないと負ける")
        }
    }

    func testBombAwareAIDoesNotCreateFourOnItself() {
        // 爆弾ルール: 自分の手を4にすると爆発して死ぬ。ミラーで自分が4になる攻撃は避ける。
        var s = makeState { $0.isBombEnabled = true; $0.isMirrorEnabled = true }
        set(&s, human: [1, 1], ai: [2, 1])
        guard case .tap(let attacker, _)? = AIEngine.chooseAction(state: s, difficulty: .hard) else {
            return XCTFail("tap expected")
        }
        XCTAssertEqual(attacker, s.player2.hands[1].id, "2の手で攻撃するとミラーで4→爆発して自滅")
    }

    func testSearchRespectsTurnLimit() {
        // 残り1ターンで判定: AIは指の合計が少ないほうが勝つことを知っている
        var s = makeState()
        set(&s, human: [2, 2], ai: [1, 1])
        s.turnCount = GameState.turnLimit - 1
        // どの手で叩いても判定でAI勝ち（手数同じ・指合計 2 < 4+1）。クラッシュせず行動を返す。
        XCTAssertNotNil(AIEngine.chooseAction(state: s, difficulty: .hard))
    }

    func testEasyAIReturnsLegalAction() {
        var s = makeState { $0.isSplittingEnabled = true; $0.isBombEnabled = true; $0.handCount = 3 }
        set(&s, human: [1, 2, 3], ai: [2, 0, 1])
        for _ in 0..<20 {
            guard let action = AIEngine.chooseAction(state: s, difficulty: .easy) else { return XCTFail() }
            switch action {
            case .tap(let a, let t):
                XCTAssertTrue(s.player2.hand(for: a)?.isAlive == true)
                XCTAssertTrue(s.player1.hand(for: t)?.isAlive == true)
            case .split(let d):
                XCTAssertTrue(s.player2.isValidSplit(newDistribution: d, allowRevival: false))
            }
        }
    }

    func testDoubleTapAIContinuesTurn() {
        var s = makeState { $0.isDoubleTapEnabled = true }
        set(&s, human: [2, 2], ai: [1, 2])
        XCTAssertNotNil(AIEngine.chooseAction(state: s, difficulty: .hard, attacksUsedThisTurn: 0))
        XCTAssertNotNil(AIEngine.chooseAction(state: s, difficulty: .hard, attacksUsedThisTurn: 1))
    }

    func testMercyBoostIncreasesRandomness() {
        // mercyBoost=0.9 なら常にランダム手（最善手の固定選択にならない）ことを統計的に確認
        var s = makeState()
        set(&s, human: [0, 2], ai: [3, 1])
        var choseOther = false
        for _ in 0..<60 {
            if case .tap(let attacker, _)? = AIEngine.chooseAction(state: s, level: 10, mercyBoost: 1.0),
               attacker != s.player2.hands[0].id {
                choseOther = true
                break
            }
        }
        XCTAssertTrue(choseOther)
    }

    func testHardSearchIsFastEnough() {
        var s = makeState { $0.isSplittingEnabled = true; $0.handCount = 3 }
        set(&s, human: [2, 3, 1], ai: [1, 2, 2])
        let start = Date()
        _ = AIEngine.chooseAction(state: s, difficulty: .hard)
        XCTAssertLessThan(Date().timeIntervalSince(start), 3.0)
    }
}
