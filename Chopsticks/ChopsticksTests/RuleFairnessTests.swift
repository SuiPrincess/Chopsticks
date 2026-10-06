import XCTest
@testable import Chopsticks

/// ルールの組み合わせが「先手でも後手でも一方的に勝ちが決まらない」ことを全探索で確かめる。
/// 先手は常に人間（プレイヤー1）。
final class RuleFairnessTests: XCTestCase {

    /// 初期局面から、`depth`手（ply）以内に一方が相手の応手によらず勝ちを強制できるかを調べる。
    /// 戻り値: +1 = 先手（プレイヤー1）の強制勝ち、-1 = 後手の強制勝ち、0 = どちらも強制できない。
    struct Solver {
        private var memo: [String: Int] = [:]

        mutating func value(_ state: GameState, attacksUsed: Int = 0, depth: Int) -> Int {
            guard depth > 0 else { return 0 }
            let key = "\(state.player1.hands.map(\.fingerCount))\(state.player2.hands.map(\.fingerCount))\(state.isPlayer1Turn)\(attacksUsed)\(depth)"
            if let cached = memo[key] { return cached }

            let player1Moves = state.isPlayer1Turn
            var best = player1Moves ? -2 : 2
            for action in AIEngine.generateAllActions(state: state) {
                var next = state
                next.apply(action)
                let value: Int
                if next.player1.isDefeated || next.player2.isDefeated {
                    // 相打ちは、とどめを刺した手番側の勝ち
                    let player1Wins = (next.player1.isDefeated && next.player2.isDefeated)
                        ? player1Moves
                        : next.player2.isDefeated
                    value = player1Wins ? 1 : -1
                } else {
                    var continues = false
                    if case .tap = action, next.config.isDoubleTapEnabled, attacksUsed == 0 { continues = true }
                    if !continues { next.switchTurn() }
                    value = self.valueOf(next, attacksUsed: continues ? 1 : 0, depth: depth - 1)
                }
                best = player1Moves ? max(best, value) : min(best, value)
                if (player1Moves && best == 1) || (!player1Moves && best == -1) { break }  // 勝ちが見つかれば十分
            }
            let result = (best == 2 || best == -2) ? 0 : best
            memo[key] = result
            return result
        }

        private mutating func valueOf(_ state: GameState, attacksUsed: Int, depth: Int) -> Int {
            value(state, attacksUsed: attacksUsed, depth: depth)
        }
    }

    private func config(_ rules: Set<FairRuleSets.Rule>) -> GameConfig {
        var config = GameConfig()
        config.gameMode = .vsAI
        FairRuleSets.apply(rules, to: &config)
        return config
    }

    // MARK: - ソルバー自体の確認（不公平な組み合わせを実際に検出できること）

    func testSolverDetectsKnownUnfairCombinations() async {
        // 爆弾+ミラー: 後手が最初の返しで連鎖爆発させて勝てる
        var bombMirror = GameConfig()
        bombMirror.gameMode = .vsAI
        bombMirror.isBombEnabled = true
        bombMirror.isMirrorEnabled = true
        var solver = Solver()
        XCTAssertEqual(solver.value(GameState(config: bombMirror), depth: 4), -1, "後手の強制勝ちを検出できる")

        // 標準ルールは短い手数では決まらない
        var standard = GameConfig()
        standard.gameMode = .vsAI
        var solver2 = Solver()
        XCTAssertEqual(solver2.value(GameState(config: standard), depth: 10), 0)
    }

    // MARK: - デイリー・おまかせで使う組み合わせはすべて公平

    func testEveryFairRuleSetHasNoForcedResultEarly() async {
        for rules in FairRuleSets.all {
            var solver = Solver()
            let depth = rules.contains(.three) ? 8 : 10
            let result = solver.value(GameState(config: config(rules)), depth: depth)
            XCTAssertEqual(result, 0, "\(rules) は\(depth)手以内に一方的な勝ちが決まってしまう")
        }
    }
}
