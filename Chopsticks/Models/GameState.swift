import Foundation

enum GamePhase: Equatable {
    case playing
    case gameOver(winnerId: UUID)
}

/// アクション適用の結果。演出（ハプティクス・エフェクト）の判断に使う。
struct ActionResult: Equatable {
    var deadHandIds: [UUID] = []
    var poisonTriggered = false
    var bombTriggered = false
}

struct GameState: Equatable {
    var player1: Player
    var player2: Player
    var currentPlayerId: UUID
    var phase: GamePhase
    var config: GameConfig
    var turnCount: Int

    init(config: GameConfig = GameConfig()) {
        let p1 = Player(name: "Player 1", handCount: config.handCount)
        let p2Name = config.gameMode == .vsAI ? "CPU" : "Player 2"
        let p2 = Player(name: p2Name, handCount: config.handCount)
        self.player1 = p1
        self.player2 = p2
        self.currentPlayerId = p1.id
        self.phase = .playing
        self.config = config
        self.turnCount = 0
    }
}

// MARK: - Turn helpers
extension GameState {
    var isPlayer1Turn: Bool { currentPlayerId == player1.id }
    var currentPlayer: Player { isPlayer1Turn ? player1 : player2 }
    var opponentPlayer: Player { isPlayer1Turn ? player2 : player1 }

    mutating func switchTurn() {
        currentPlayerId = isPlayer1Turn ? player2.id : player1.id
        turnCount += 1
    }
}

// MARK: - Rule application
extension GameState {
    /// 現在の手番プレイヤーのアクションを、全ルール（毒・ミラー・爆弾を含む）に
    /// 従って適用する。手番の切り替えは行わない。
    /// 実プレイ（ViewModel）とAIのシミュレーションの両方がここを通ることで、
    /// ルールの実装が常に一致する。
    @discardableResult
    mutating func apply(_ action: GameAction) -> ActionResult {
        var result = ActionResult()
        switch action {
        case .tap(let attackerHandId, let targetHandId):
            applyTap(attackerHandId: attackerHandId, targetHandId: targetHandId, result: &result)
        case .split(let newDistribution):
            applySplit(newDistribution)
        }
        if config.isBombEnabled {
            processBombs(result: &result)
        }
        return result
    }

    private mutating func applyTap(attackerHandId: UUID, targetHandId: UUID, result: inout ActionResult) {
        guard let attackerHand = currentPlayer.hand(for: attackerHandId), attackerHand.isAlive,
              let targetHand = opponentPlayer.hand(for: targetHandId), targetHand.isAlive
        else { return }

        let overflowWraps = config.isOverflowWrapEnabled
        let attackingFingers = attackerHand.fingerCount

        // 毒: 指1本で攻撃すると相手の手を即死させる
        if config.isPoisonEnabled && attackingFingers == 1 {
            withOpponentPlayer { player in
                player.updateHand(id: targetHandId) { $0.fingerCount = 0 }
            }
            result.poisonTriggered = true
        } else {
            withOpponentPlayer { player in
                player.updateHand(id: targetHandId) {
                    $0.receiveTap(from: attackingFingers, overflowWraps: overflowWraps)
                }
            }
        }
        if opponentPlayer.hand(for: targetHandId)?.isAlive == false {
            result.deadHandIds.append(targetHandId)
        }

        // ミラー: 攻撃した本数が自分の手にも加算される
        if config.isMirrorEnabled {
            withCurrentPlayer { player in
                player.updateHand(id: attackerHandId) {
                    $0.receiveTap(from: attackingFingers, overflowWraps: overflowWraps)
                }
            }
            if currentPlayer.hand(for: attackerHandId)?.isAlive == false {
                result.deadHandIds.append(attackerHandId)
            }
        }
    }

    private mutating func applySplit(_ newDistribution: [Int]) {
        guard config.isSplittingEnabled,
              currentPlayer.isValidSplit(
                newDistribution: newDistribution,
                allowRevival: config.isDeadHandRevivalEnabled
              )
        else { return }
        withCurrentPlayer { player in
            for (i, count) in newDistribution.enumerated() {
                player.hands[i].fingerCount = count
            }
        }
    }

    /// 爆弾: ちょうど4本になった手は爆発して死に、他の全ての生きた手に1ダメージ（連鎖あり）
    private mutating func processBombs(result: inout ActionResult) {
        var exploded: Set<UUID> = []
        var didExplode = true

        while didExplode {
            didExplode = false

            for hand in player1.hands + player2.hands {
                guard hand.fingerCount == 4, hand.isAlive, !exploded.contains(hand.id) else { continue }
                exploded.insert(hand.id)
                didExplode = true
                result.bombTriggered = true
                result.deadHandIds.append(hand.id)

                if let idx = player1.handIndex(for: hand.id) {
                    player1.hands[idx].fingerCount = 0
                } else if let idx = player2.handIndex(for: hand.id) {
                    player2.hands[idx].fingerCount = 0
                }

                let overflowWraps = config.isOverflowWrapEnabled
                for i in player1.hands.indices where player1.hands[i].id != hand.id {
                    player1.hands[i].receiveTap(from: 1, overflowWraps: overflowWraps)
                }
                for i in player2.hands.indices where player2.hands[i].id != hand.id {
                    player2.hands[i].receiveTap(from: 1, overflowWraps: overflowWraps)
                }
            }
        }
    }

    private mutating func withCurrentPlayer(_ body: (inout Player) -> Void) {
        if isPlayer1Turn { body(&player1) } else { body(&player2) }
    }

    private mutating func withOpponentPlayer(_ body: (inout Player) -> Void) {
        if isPlayer1Turn { body(&player2) } else { body(&player1) }
    }
}
