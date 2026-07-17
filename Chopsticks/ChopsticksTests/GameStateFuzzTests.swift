import XCTest
@testable import Chopsticks

/// シード付きランダムプレイアウトによるファズテスト。
/// ランダムなルール組合せで実際のGameViewModelを大量に対局させ、
/// どの経路でもルールの不変条件が破れないことを検証する。
/// シードは固定なので失敗は常に再現可能。
@MainActor
final class GameStateFuzzTests: XCTestCase {

    override func setUp() {
        super.setUp()
        GameSessionStore.shared.clear()
    }

    override func tearDown() {
        GameSessionStore.shared.clear()
        super.tearDown()
    }

    // MARK: - Fuzz drivers

    /// ランダムなルール設定で30局。全アクションで不変条件を検証し、
    /// 決着後はリプレイが実対局の全盤面と完全一致することを確認する。
    func testRandomPlayoutsAcrossRuleCombinations() throws {
        for seed in 1...30 {
            var rng = SplitMix64(state: UInt64(seed))
            let config = randomConfig(using: &rng)
            try runPlayout(config: config, rng: &rng, context: "seed=\(seed) config=\(config)")
        }
    }

    /// 特殊ルール全部乗せ（3本手・毒・爆弾・ミラー・ダブルタップ・分割・復活）で10局。
    /// ルール同士の相互作用（毒×ミラー、爆弾連鎖×wrap等）を集中的に踏む。
    func testAllRulesEnabledPlayouts() throws {
        var config = GameConfig()
        config.gameMode = .localTwoPlayer
        config.isOverflowWrapEnabled = true
        config.isSplittingEnabled = true
        config.isDeadHandRevivalEnabled = true
        config.handCount = 3
        config.isPoisonEnabled = true
        config.isBombEnabled = true
        config.isMirrorEnabled = true
        config.isDoubleTapEnabled = true

        for seed in 100...109 {
            var rng = SplitMix64(state: UInt64(seed))
            try runPlayout(config: config, rng: &rng, context: "allRules seed=\(seed)")
        }
    }

    // MARK: - Playout

    private func runPlayout(config: GameConfig, rng: inout SplitMix64, context: String) throws {
        let viewModel = GameViewModel(config: config)
        var vmStates: [GameState] = [viewModel.state]
        var performedCount = 0

        while !viewModel.isGameOver && performedCount < 300 {
            let available = AIEngine.generateAllActions(state: viewModel.state)
            assertActionsLegal(available, state: viewModel.state, context: context)

            let action = available[Int(rng.next() % UInt64(available.count))]
            let stateBefore = viewModel.state
            let deadBefore = deadHandIds(stateBefore)

            switch action {
            case .tap(let attackerHandId, let targetHandId):
                viewModel.handleHandTap(attackerHandId)
                viewModel.handleHandTap(targetHandId)
            case .split(let newDistribution):
                viewModel.performSplit(newDistribution: newDistribution)
            }
            performedCount += 1

            let state = viewModel.state
            XCTAssertNotEqual(state, stateBefore, "合法手は必ず盤面を変える \(context)")
            assertStateInvariants(state, context: context)

            // タップ（毒・ミラー・爆弾含む）で死んだ手が勝手に生き返らない
            if case .tap = action {
                XCTAssertTrue(
                    deadBefore.isSubset(of: deadHandIds(state)),
                    "タップで死んだ手は復活しない \(context)"
                )
            }

            // ターンは1つずつしか進まない。進まないのはダブルタップ継続か決着時のみ
            let delta = state.turnCount - stateBefore.turnCount
            XCTAssertTrue(delta == 0 || delta == 1, "ターンの飛び越しはない \(context)")
            if delta == 0 {
                var wasTap = false
                if case .tap = action { wasTap = true }
                XCTAssertTrue(
                    viewModel.isGameOver || (wasTap && config.isDoubleTapEnabled),
                    "ターンが進まないのはダブルタップ継続か決着時のみ \(context)"
                )
            }

            // Codable往復（保存・マルチプレイ同期と同じ経路）で盤面が完全に保たれる
            if performedCount % 7 == 0 || viewModel.isGameOver {
                let data = try JSONEncoder().encode(state)
                let decoded = try JSONDecoder().decode(GameState.self, from: data)
                XCTAssertEqual(decoded, state, "Codable往復で盤面が変わらない \(context)")
            }

            vmStates.append(state)
        }

        // ターン上限のサドンデス判定があるため、必ず有限手数で決着する
        XCTAssertTrue(viewModel.isGameOver, "全ての対局は必ず決着する \(context)")
        XCTAssertLessThanOrEqual(viewModel.state.turnCount, GameRules.turnLimit, context)

        // リプレイの再構築が実対局の全盤面列と完全一致する
        let replay = try XCTUnwrap(viewModel.lastReplay, "決着時はリプレイが残る \(context)")
        XCTAssertEqual(replay.actions.count, performedCount, context)
        let snapshots = ReplaySimulator.snapshots(for: replay)
        XCTAssertEqual(snapshots, vmStates, "リプレイ再構築が実対局と完全一致する \(context)")
    }

    // MARK: - Invariants

    private func randomConfig(using rng: inout SplitMix64) -> GameConfig {
        var config = GameConfig()
        config.gameMode = .localTwoPlayer
        config.isOverflowWrapEnabled = Bool.random(using: &rng)
        config.isSplittingEnabled = Bool.random(using: &rng)
        config.isDeadHandRevivalEnabled = config.isSplittingEnabled && Bool.random(using: &rng)
        config.handCount = Bool.random(using: &rng) ? 3 : 2
        config.isPoisonEnabled = Bool.random(using: &rng)
        config.isBombEnabled = Bool.random(using: &rng)
        config.isMirrorEnabled = Bool.random(using: &rng)
        config.isDoubleTapEnabled = Bool.random(using: &rng)
        return config
    }

    private func deadHandIds(_ state: GameState) -> Set<UUID> {
        Set((state.player1.hands + state.player2.hands).filter { !$0.isAlive }.map(\.id))
    }

    private func assertStateInvariants(_ state: GameState, context: String) {
        for hand in state.player1.hands + state.player2.hands {
            XCTAssertTrue(
                (0...4).contains(hand.fingerCount),
                "指は常に0〜4本（実際: \(hand.fingerCount)） \(context)"
            )
        }
        XCTAssertEqual(state.player1.hands.count, state.config.handCount, context)
        XCTAssertEqual(state.player2.hands.count, state.config.handCount, context)
        XCTAssertLessThanOrEqual(state.turnCount, GameRules.turnLimit, context)
    }

    /// 生成された全アクションが現盤面で合法であることを検証する
    private func assertActionsLegal(_ actions: [GameAction], state: GameState, context: String) {
        XCTAssertFalse(actions.isEmpty, "決着前は必ず合法手が存在する \(context)")
        let current = state.currentPlayer
        let opponent = state.opponentPlayer
        for action in actions {
            switch action {
            case .tap(let attackerHandId, let targetHandId):
                XCTAssertEqual(
                    current.hand(for: attackerHandId)?.isAlive, true,
                    "攻撃手は自分の生きた手 \(context)"
                )
                XCTAssertEqual(
                    opponent.hand(for: targetHandId)?.isAlive, true,
                    "攻撃対象は相手の生きた手 \(context)"
                )
            case .split(let newDistribution):
                XCTAssertTrue(
                    current.isValidSplit(
                        newDistribution: newDistribution,
                        allowRevival: state.config.isDeadHandRevivalEnabled
                    ),
                    "生成された分割は必ず合法 \(context)"
                )
            }
        }
    }
}
