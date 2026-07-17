import Foundation

struct AIEngine {

    // MARK: - Public

    /// 現在の手番プレイヤー（AI）の行動を選ぶ。行動が存在しない場合のみnil（通常起こらない）。
    /// 探索は同期的に実行されるため、呼び出し側はメインアクター外で実行すること。
    static func chooseAction(
        state: GameState,
        difficulty: AIDifficulty,
        attacksUsedThisTurn: Int = 0
    ) -> GameAction? {
        let actions = orderedActions(state: state)
        guard !actions.isEmpty else { return nil }

        switch difficulty {
        case .easy:
            return actions.randomElement()
        case .hard:
            return chooseBestAction(
                state: state,
                actions: actions,
                attacksUsed: attacksUsedThisTurn,
                maxDepth: 10,
                thinkTime: .milliseconds(200)
            )
        case .oni:
            return chooseBestAction(
                state: state,
                actions: actions,
                attacksUsed: attacksUsedThisTurn,
                maxDepth: 16,
                thinkTime: .milliseconds(450)
            )
        }
    }

    /// ランク戦用: レベル1〜10で段階的に強くなる。
    /// 低レベルはランダム行動が混ざり、高レベルほど深く読む。
    static func chooseAction(
        state: GameState,
        level: Int,
        attacksUsedThisTurn: Int = 0
    ) -> GameAction? {
        let actions = orderedActions(state: state)
        guard !actions.isEmpty else { return nil }

        let clamped = min(max(level, 1), 10)
        // Lv.1: 76%ランダム → Lv.10: 0%ランダム
        let randomMoveChance = max(0.0, 0.85 - 0.09 * Double(clamped))
        if Double.random(in: 0..<1) < randomMoveChance {
            return actions.randomElement()
        }
        // Lv.1: 2手読み → Lv.10: 11手読み
        return chooseBestAction(
            state: state,
            actions: actions,
            attacksUsed: attacksUsedThisTurn,
            maxDepth: 1 + clamped,
            thinkTime: .milliseconds(250)
        )
    }

    // MARK: - Action Generation

    static func generateAllActions(state: GameState) -> [GameAction] {
        let current = state.currentPlayer
        let opponent = state.opponentPlayer
        var actions: [GameAction] = []

        // タップアクション: 自分の生きてる手 × 相手の生きてる手
        for myHand in current.aliveHands {
            for theirHand in opponent.aliveHands {
                actions.append(.tap(attackerHandId: myHand.id, targetHandId: theirHand.id))
            }
        }

        // 分割アクション
        if state.config.isSplittingEnabled {
            let allowRevival = state.config.isDeadHandRevivalEnabled
            for distribution in distributions(total: current.totalFingers, handCount: current.hands.count)
            where current.isValidSplit(newDistribution: distribution, allowRevival: allowRevival) {
                actions.append(.split(newDistribution: distribution))
            }
        }

        return actions
    }

    /// αβ枝刈りの効率を上げるため、即キルになるタップを先頭に並べる
    static func orderedActions(state: GameState) -> [GameAction] {
        let actions = generateAllActions(state: state)
        guard actions.count > 1 else { return actions }
        let current = state.currentPlayer
        let opponent = state.opponentPlayer

        func isKillTap(_ action: GameAction) -> Bool {
            guard case .tap(let attackerId, let targetId) = action,
                  let attacker = current.hand(for: attackerId),
                  let target = opponent.hand(for: targetId) else { return false }
            if state.config.isPoisonEnabled && attacker.fingerCount == 1 { return true }
            let sum = target.fingerCount + attacker.fingerCount
            return state.config.isOverflowWrapEnabled ? sum == 5 : sum >= 5
        }

        // 安定パーティション: キル手 → その他タップ → 分割
        var kills: [GameAction] = []
        var taps: [GameAction] = []
        var splits: [GameAction] = []
        for action in actions {
            if case .split = action {
                splits.append(action)
            } else if isKillTap(action) {
                kills.append(action)
            } else {
                taps.append(action)
            }
        }
        return kills + taps + splits
    }

    /// total本の指をhandCount個の手へ0〜4本ずつ配る全パターン
    private static func distributions(total: Int, handCount: Int) -> [[Int]] {
        guard handCount > 0 else { return total == 0 ? [[]] : [] }
        guard total <= handCount * 4 else { return [] }
        var results: [[Int]] = []
        for count in 0...min(total, 4) {
            for rest in distributions(total: total - count, handCount: handCount - 1) {
                results.append([count] + rest)
            }
        }
        return results
    }

    // MARK: - 探索（反復深化 + αβ枝刈り）

    private static let winScore = 100_000

    /// 探索の中断判定。ノード数ベースで時々時計を見る。
    private final class SearchContext {
        let clock = ContinuousClock()
        let deadline: ContinuousClock.Instant
        var nodes = 0
        var aborted = false

        init(thinkTime: Duration) {
            deadline = clock.now.advanced(by: thinkTime)
        }

        /// trueなら探索を打ち切る
        func shouldAbort() -> Bool {
            if aborted { return true }
            nodes += 1
            if nodes & 0x3FF == 0, clock.now >= deadline {
                aborted = true
            }
            return aborted
        }
    }

    /// 反復深化: 深さ1から順に読み、時間切れになったら最後に完了した深さの結果を使う。
    /// これにより盤面の複雑さによらず応答時間が一定に保たれる。
    /// （テストから短い持ち時間で呼べるようinternal）
    static func chooseBestAction(
        state: GameState,
        actions: [GameAction],
        attacksUsed: Int,
        maxDepth: Int,
        thinkTime: Duration
    ) -> GameAction {
        let aiId = state.currentPlayerId
        let context = SearchContext(thinkTime: thinkTime)
        var bestActions: [GameAction] = []

        for depth in 1...max(1, maxDepth) {
            var iterationBest = Int.min
            var iterationActions: [GameAction] = []

            for action in actions {
                let score = search(
                    action,
                    in: state,
                    attacksUsed: attacksUsed,
                    depth: depth,
                    alpha: Int.min,
                    beta: Int.max,
                    aiId: aiId,
                    ply: 1,
                    context: context
                )
                if context.aborted { break }
                if score > iterationBest {
                    iterationBest = score
                    iterationActions = [action]
                } else if score == iterationBest {
                    iterationActions.append(action)
                }
            }

            // 中断された深さの結果は不完全なので捨てる
            if context.aborted {
                if bestActions.isEmpty { bestActions = iterationActions }
                break
            }
            bestActions = iterationActions

            // 必勝/必敗が確定したらこれ以上深く読む意味がない
            if iterationBest >= winScore - 100 || iterationBest <= -winScore + 100 {
                break
            }
        }

        // 同点の最善手からランダムに選び、行動を予測されにくくする
        return bestActions.randomElement() ?? actions[0]
    }

    /// actionを適用した後の局面をAI視点で評価する（ミニマックス + αβ枝刈り）
    private static func search(
        _ action: GameAction,
        in state: GameState,
        attacksUsed: Int,
        depth: Int,
        alpha: Int,
        beta: Int,
        aiId: UUID,
        ply: Int,
        context: SearchContext
    ) -> Int {
        if context.shouldAbort() { return 0 }

        var next = state
        next.apply(action)

        // 終局判定（plyの分だけ減点し、早い勝ち・遅い負けを好む）
        // 相打ちはとどめを刺した手番側（next.currentPlayerIdはまだ切替前）の勝ち
        let ai = aiId == next.player1.id ? next.player1 : next.player2
        let opponent = aiId == next.player1.id ? next.player2 : next.player1
        if ai.isDefeated || opponent.isDefeated {
            let aiWins = (ai.isDefeated && opponent.isDefeated)
                ? next.currentPlayerId == aiId
                : opponent.isDefeated
            return aiWins ? winScore - ply : -winScore + ply
        }

        // ダブルタップ: 1回目の攻撃なら同じプレイヤーがもう一度行動
        var continuesTurn = false
        if case .tap = action, next.config.isDoubleTapEnabled, attacksUsed == 0 {
            continuesTurn = true
        }
        let nextAttacksUsed = continuesTurn ? 1 : 0
        if !continuesTurn {
            next.switchTurn()
        }

        // 評価関数はテンポ（手番側の即キル脅威）を見るため、手番切替後に評価する
        if depth <= 0 { return evaluateState(next, for: aiId) }

        let moves = orderedActions(state: next)
        guard !moves.isEmpty else { return evaluateState(next, for: aiId) }

        var alpha = alpha
        var beta = beta
        if next.currentPlayerId == aiId {
            var best = Int.min
            for move in moves {
                best = max(best, search(
                    move, in: next, attacksUsed: nextAttacksUsed,
                    depth: depth - 1, alpha: alpha, beta: beta, aiId: aiId, ply: ply + 1,
                    context: context
                ))
                if context.aborted { return best }
                alpha = max(alpha, best)
                if alpha >= beta { break }
            }
            return best
        } else {
            var best = Int.max
            for move in moves {
                best = min(best, search(
                    move, in: next, attacksUsed: nextAttacksUsed,
                    depth: depth - 1, alpha: alpha, beta: beta, aiId: aiId, ply: ply + 1,
                    context: context
                ))
                if context.aborted { return best }
                beta = min(beta, best)
                if alpha >= beta { break }
            }
            return best
        }
    }

    // MARK: - 評価関数

    static func evaluateState(_ state: GameState, for playerId: UUID) -> Int {
        let me = playerId == state.player1.id ? state.player1 : state.player2
        let them = playerId == state.player1.id ? state.player2 : state.player1

        var score = 0

        // 生きている手の数の差が支配的な要素
        score += (me.aliveHands.count - them.aliveHands.count) * 55

        // 相手の手は5（死）に近いほど良い
        for hand in them.aliveHands {
            score += hand.fingerCount * 3
            if hand.fingerCount == 4 { score += 18 }
        }

        // 自分の手は指が少ないほど安全
        for hand in me.aliveHands {
            score -= hand.fingerCount
            if hand.fingerCount == 4 { score -= 15 }
        }

        // 分割ありなら指の合計は組み替えの柔軟性（リソース）でもある
        if state.config.isSplittingEnabled {
            score += min(me.totalFingers, me.hands.count * 4) / 2
        }

        // テンポ: 手番側に即キルできる手があるなら大きな脅威
        if let bonus = killThreatBonus(state) {
            score += state.currentPlayerId == playerId ? bonus : -bonus
        }

        return score
    }

    /// 手番側が相手の手を一撃で殺せる手を持つならそのボーナス値、なければnil
    private static func killThreatBonus(_ state: GameState) -> Int? {
        let mover = state.currentPlayer
        let target = state.opponentPlayer
        let wraps = state.config.isOverflowWrapEnabled
        let poison = state.config.isPoisonEnabled

        for attacker in mover.aliveHands {
            // 毒: 指1本の攻撃は相討ちの即死。純粋なキルより価値は低い
            if poison && attacker.fingerCount == 1 && !target.aliveHands.isEmpty {
                return 18
            }
            for victim in target.aliveHands {
                let sum = victim.fingerCount + attacker.fingerCount
                if wraps ? sum == 5 : sum >= 5 { return 25 }
            }
        }
        return nil
    }
}
