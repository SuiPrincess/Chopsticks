import Foundation

struct AIEngine {

    // MARK: - Public

    static func chooseAction(state: GameState, difficulty: AIDifficulty) -> GameAction {
        let actions = generateAllActions(state: state)
        guard !actions.isEmpty else {
            // フォールバック: 何もできない場合（通常起こらない）
            return actions.first ?? .tap(attackerHandId: UUID(), targetHandId: UUID())
        }

        switch difficulty {
        case .easy:
            return actions.randomElement()!
        case .hard:
            return chooseBestAction(state: state, actions: actions)
        }
    }

    // MARK: - Action Generation

    static func generateAllActions(state: GameState) -> [GameAction] {
        let current = state.currentPlayerId == state.player1.id ? state.player1 : state.player2
        let opponent = state.currentPlayerId == state.player1.id ? state.player2 : state.player1
        var actions: [GameAction] = []

        // タップアクション: 自分の生きてる手 × 相手の生きてる手
        let myAlive = current.hands.filter { $0.isAlive }
        let theirAlive = opponent.hands.filter { $0.isAlive }

        for myHand in myAlive {
            for theirHand in theirAlive {
                actions.append(.tap(attackerHandId: myHand.id, targetHandId: theirHand.id))
            }
        }

        // 分割アクション
        if state.config.isSplittingEnabled {
            let total = current.totalFingers
            let handCount = current.hands.count
            let allowRevival = state.config.isDeadHandRevivalEnabled

            if handCount == 2 {
                for left in 0...min(total, 4) {
                    let right = total - left
                    if right >= 0 && right <= 4 {
                        if current.isValidSplit(newDistribution: [left, right], allowRevival: allowRevival) {
                            actions.append(.split(newDistribution: [left, right]))
                        }
                    }
                }
            } else if handCount == 3 {
                for a in 0...min(total, 4) {
                    for b in 0...min(total - a, 4) {
                        let c = total - a - b
                        if c >= 0 && c <= 4 {
                            if current.isValidSplit(newDistribution: [a, b, c], allowRevival: allowRevival) {
                                actions.append(.split(newDistribution: [a, b, c]))
                            }
                        }
                    }
                }
            }
        }

        return actions
    }

    // MARK: - Hard AI: 1手先読み評価

    private static func chooseBestAction(state: GameState, actions: [GameAction]) -> GameAction {
        var bestAction = actions[0]
        var bestScore = Int.min

        for action in actions {
            let score = evaluateAction(action, state: state)
            if score > bestScore {
                bestScore = score
                bestAction = action
            }
        }

        return bestAction
    }

    private static func evaluateAction(_ action: GameAction, state: GameState) -> Int {
        var simState = state
        let isP1 = simState.currentPlayerId == simState.player1.id
        let overflowWraps = simState.config.isOverflowWrapEnabled

        switch action {
        case .tap(let attackerHandId, let targetHandId):
            let attackerHand = isP1
                ? simState.player1.hand(for: attackerHandId)
                : simState.player2.hand(for: attackerHandId)
            guard let attacker = attackerHand else { return -100 }

            // 毒ルール
            if simState.config.isPoisonEnabled && attacker.fingerCount == 1 {
                if isP1 {
                    simState.player2.updateHand(id: targetHandId) { $0.fingerCount = 0 }
                } else {
                    simState.player1.updateHand(id: targetHandId) { $0.fingerCount = 0 }
                }
            } else {
                if isP1 {
                    simState.player2.updateHand(id: targetHandId) { hand in
                        hand.receiveTap(from: attacker.fingerCount, overflowWraps: overflowWraps)
                    }
                } else {
                    simState.player1.updateHand(id: targetHandId) { hand in
                        hand.receiveTap(from: attacker.fingerCount, overflowWraps: overflowWraps)
                    }
                }
            }

            // ミラー
            if simState.config.isMirrorEnabled {
                if isP1 {
                    simState.player1.updateHand(id: attackerHandId) { hand in
                        hand.receiveTap(from: attacker.fingerCount, overflowWraps: overflowWraps)
                    }
                } else {
                    simState.player2.updateHand(id: attackerHandId) { hand in
                        hand.receiveTap(from: attacker.fingerCount, overflowWraps: overflowWraps)
                    }
                }
            }

        case .split(let distribution):
            if isP1 {
                for (i, count) in distribution.enumerated() {
                    simState.player1.hands[i] = Hand(id: simState.player1.hands[i].id, fingerCount: count)
                }
            } else {
                for (i, count) in distribution.enumerated() {
                    simState.player2.hands[i] = Hand(id: simState.player2.hands[i].id, fingerCount: count)
                }
            }
        }

        return evaluateState(simState, for: state.currentPlayerId)
    }

    private static func evaluateState(_ state: GameState, for playerId: UUID) -> Int {
        let me = playerId == state.player1.id ? state.player1 : state.player2
        let them = playerId == state.player1.id ? state.player2 : state.player1

        // 勝利/敗北
        if them.isDefeated { return 1000 }
        if me.isDefeated { return -1000 }

        var score = 0

        // 相手のダメージを最大化
        let theirDead = them.hands.filter { !$0.isAlive }.count
        score += theirDead * 50

        // 相手の合計指を最小化（5に近いほど良い）
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
