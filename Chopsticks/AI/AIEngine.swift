import Foundation

struct AIEngine {

    // MARK: - Public

    /// 現在の手番プレイヤー（AI）の行動を選ぶ。行動が存在しない場合のみnil（通常起こらない）。
    static func chooseAction(
        state: GameState,
        difficulty: AIDifficulty,
        attacksUsedThisTurn: Int = 0
    ) -> GameAction? {
        let actions = generateAllActions(state: state)
        guard !actions.isEmpty else { return nil }

        switch difficulty {
        case .easy:
            return actions.randomElement()
        case .hard:
            return chooseBestAction(state: state, actions: actions, attacksUsed: attacksUsedThisTurn)
        }
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

    // MARK: - Hard AI: αβ探索

    private static let winScore = 1000

    /// 分岐数が多い設定ほど浅くして応答時間を一定に保つ
    private static func searchDepth(for state: GameState) -> Int {
        let splitting = state.config.isSplittingEnabled
        let manyHands = state.player1.hands.count >= 3
        if splitting && manyHands { return 4 }
        if splitting || manyHands { return 5 }
        return 6
    }

    private static func chooseBestAction(state: GameState, actions: [GameAction], attacksUsed: Int) -> GameAction {
        let aiId = state.currentPlayerId
        let depth = searchDepth(for: state)
        var bestScore = Int.min
        var bestActions: [GameAction] = []

        for action in actions {
            let score = search(
                action,
                in: state,
                attacksUsed: attacksUsed,
                depth: depth,
                alpha: Int.min,
                beta: Int.max,
                aiId: aiId,
                ply: 1
            )
            if score > bestScore {
                bestScore = score
                bestActions = [action]
            } else if score == bestScore {
                bestActions.append(action)
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
        ply: Int
    ) -> Int {
        var next = state
        next.apply(action)

        // 終局判定（plyの分だけ減点し、早い勝ち・遅い負けを好む）
        let ai = aiId == next.player1.id ? next.player1 : next.player2
        let opponent = aiId == next.player1.id ? next.player2 : next.player1
        if ai.isDefeated { return -winScore + ply }
        if opponent.isDefeated { return winScore - ply }

        if depth <= 0 { return evaluateState(next, for: aiId) }

        // ダブルタップ: 1回目の攻撃なら同じプレイヤーがもう一度行動
        var continuesTurn = false
        if case .tap = action, next.config.isDoubleTapEnabled, attacksUsed == 0 {
            continuesTurn = true
        }
        let nextAttacksUsed = continuesTurn ? 1 : 0
        if !continuesTurn {
            next.switchTurn()
        }

        let moves = generateAllActions(state: next)
        guard !moves.isEmpty else { return evaluateState(next, for: aiId) }

        var alpha = alpha
        var beta = beta
        if next.currentPlayerId == aiId {
            var best = Int.min
            for move in moves {
                best = max(best, search(
                    move, in: next, attacksUsed: nextAttacksUsed,
                    depth: depth - 1, alpha: alpha, beta: beta, aiId: aiId, ply: ply + 1
                ))
                alpha = max(alpha, best)
                if alpha >= beta { break }
            }
            return best
        } else {
            var best = Int.max
            for move in moves {
                best = min(best, search(
                    move, in: next, attacksUsed: nextAttacksUsed,
                    depth: depth - 1, alpha: alpha, beta: beta, aiId: aiId, ply: ply + 1
                ))
                beta = min(beta, best)
                if alpha >= beta { break }
            }
            return best
        }
    }

    // MARK: - 評価関数

    private static func evaluateState(_ state: GameState, for playerId: UUID) -> Int {
        let me = playerId == state.player1.id ? state.player1 : state.player2
        let them = playerId == state.player1.id ? state.player2 : state.player1

        var score = 0

        // 相手のダメージを最大化
        let theirDead = them.hands.filter { !$0.isAlive }.count
        score += theirDead * 50

        // 相手の指が多い（5に近い）ほど良い
        for hand in them.aliveHands {
            if hand.fingerCount == 4 { score += 20 }
            score += hand.fingerCount * 3
        }

        // 自分の手を守る
        let myDead = me.hands.filter { !$0.isAlive }.count
        score -= myDead * 40

        // 自分の指が少ない方が安全
        for hand in me.aliveHands {
            if hand.fingerCount == 4 { score -= 15 }
        }

        return score
    }
}
