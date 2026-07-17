import XCTest
@testable import Chopsticks

@MainActor
final class GameViewModelTests: XCTestCase {

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
