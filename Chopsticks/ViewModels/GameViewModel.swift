import SwiftUI

@Observable
@MainActor
final class GameViewModel {
    // MARK: - State
    private(set) var state: GameState
    private(set) var selectedAttackerHandId: UUID?
    private(set) var lastDeadHandId: UUID?
    private(set) var attacksThisTurn: Int = 0
    private(set) var isAIThinking: Bool = false
    var showSplitPanel: Bool = false
    var showRules: Bool = false

    // MARK: - Computed
    var currentPlayer: Player {
        state.currentPlayerId == state.player1.id ? state.player1 : state.player2
    }

    var opponentPlayer: Player {
        state.currentPlayerId == state.player1.id ? state.player2 : state.player1
    }

    var isGameOver: Bool {
        if case .gameOver = state.phase { return true }
        return false
    }

    var winnerName: String? {
        guard case .gameOver(let winnerId) = state.phase else { return nil }
        return winnerId == state.player1.id ? state.player1.name : state.player2.name
    }

    var isPlayer1Turn: Bool {
        state.currentPlayerId == state.player1.id
    }

    var config: GameConfig { state.config }

    var isAITurn: Bool {
        state.config.gameMode == .vsAI && state.currentPlayerId == state.player2.id
    }

    var isVsAI: Bool {
        state.config.gameMode == .vsAI
    }

    // MARK: - Init
    init(config: GameConfig = GameConfig()) {
        self.state = GameState(config: config)
    }

    // MARK: - Actions
    func newGame() {
        state = GameState(config: state.config)
        selectedAttackerHandId = nil
        lastDeadHandId = nil
        attacksThisTurn = 0
        showSplitPanel = false
        isAIThinking = false
    }

    func selectAttackerHand(_ handId: UUID) {
        guard case .playing = state.phase else { return }
        guard !isAITurn else { return }
        let player = currentPlayer
        guard let hand = player.hand(for: handId), hand.isAlive else { return }

        if selectedAttackerHandId == handId {
            selectedAttackerHandId = nil
        } else {
            selectedAttackerHandId = handId
            HapticManager.handSelect()
        }
    }

    func tapOpponentHand(_ targetHandId: UUID) {
        guard case .playing = state.phase else { return }
        guard let attackerHandId = selectedAttackerHandId else { return }

        let attacker = currentPlayer
        let opponent = opponentPlayer
        let overflowWraps = config.isOverflowWrapEnabled

        guard let attackerHand = attacker.hand(for: attackerHandId), attackerHand.isAlive else { return }
        guard let targetHand = opponent.hand(for: targetHandId), targetHand.isAlive else { return }

        let isP1Turn = state.currentPlayerId == state.player1.id

        // 毒ルール: 指1本で攻撃→即死
        if config.isPoisonEnabled && attackerHand.fingerCount == 1 {
            if isP1Turn {
                state.player2.updateHand(id: targetHandId) { $0.fingerCount = 0 }
            } else {
                state.player1.updateHand(id: targetHandId) { $0.fingerCount = 0 }
            }
            lastDeadHandId = targetHandId
            HapticManager.poisonKill()
        } else {
            // 通常攻撃
            if isP1Turn {
                state.player2.updateHand(id: targetHandId) { hand in
                    hand.receiveTap(from: attackerHand.fingerCount, overflowWraps: overflowWraps)
                }
                if !(state.player2.hand(for: targetHandId)?.isAlive ?? true) {
                    lastDeadHandId = targetHandId
                }
            } else {
                state.player1.updateHand(id: targetHandId) { hand in
                    hand.receiveTap(from: attackerHand.fingerCount, overflowWraps: overflowWraps)
                }
                if !(state.player1.hand(for: targetHandId)?.isAlive ?? true) {
                    lastDeadHandId = targetHandId
                }
            }
            HapticManager.handTap()
        }

        // ミラールール: 攻撃側にも同じ加算
        if config.isMirrorEnabled {
            let damage = attackerHand.fingerCount
            if isP1Turn {
                state.player1.updateHand(id: attackerHandId) { hand in
                    hand.receiveTap(from: damage, overflowWraps: overflowWraps)
                }
            } else {
                state.player2.updateHand(id: attackerHandId) { hand in
                    hand.receiveTap(from: damage, overflowWraps: overflowWraps)
                }
            }
        }

        // 爆弾ルール: 手が4になったら爆発
        if config.isBombEnabled {
            processBombs()
        }

        selectedAttackerHandId = nil

        if checkWinCondition() { return }

        // ダブルタップ: 1ターンに2回攻撃
        if config.isDoubleTapEnabled && attacksThisTurn == 0 {
            attacksThisTurn = 1
            if isAITurn { triggerAITurn() }
            return
        }

        attacksThisTurn = 0
        advanceTurn()
    }

    func performSplit(newDistribution: [Int]) {
        guard case .playing = state.phase else { return }
        guard config.isSplittingEnabled else { return }
        let allowRevival = config.isDeadHandRevivalEnabled
        guard currentPlayer.isValidSplit(newDistribution: newDistribution, allowRevival: allowRevival) else { return }

        let isP1Turn = state.currentPlayerId == state.player1.id
        for (i, count) in newDistribution.enumerated() {
            if isP1Turn {
                state.player1.hands[i] = Hand(id: state.player1.hands[i].id, fingerCount: count)
            } else {
                state.player2.hands[i] = Hand(id: state.player2.hands[i].id, fingerCount: count)
            }
        }

        HapticManager.split()
        showSplitPanel = false
        selectedAttackerHandId = nil
        attacksThisTurn = 0
        advanceTurn()
    }

    func handleHandTap(_ handId: UUID) {
        guard case .playing = state.phase else { return }
        guard !isAITurn else { return }

        let current = currentPlayer
        let opponent = opponentPlayer

        let isOwnHand = current.hand(for: handId) != nil
        let isOpponentHand = opponent.hand(for: handId) != nil

        if isOwnHand {
            selectAttackerHand(handId)
        } else if isOpponentHand, selectedAttackerHandId != nil {
            tapOpponentHand(handId)
        }
    }

    // MARK: - AI
    func triggerAITurn() {
        guard isAITurn, case .playing = state.phase else { return }
        isAIThinking = true

        let currentState = state
        let difficulty = config.aiDifficulty

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard case .playing = self.state.phase else { return }

            let action = AIEngine.chooseAction(state: currentState, difficulty: difficulty)
            self.isAIThinking = false
            self.executeAIAction(action)
        }
    }

    private func executeAIAction(_ action: GameAction) {
        switch action {
        case .tap(let attackerHandId, let targetHandId):
            selectedAttackerHandId = attackerHandId
            tapOpponentHand(targetHandId)
        case .split(let distribution):
            performSplit(newDistribution: distribution)
        }
    }

    // MARK: - Bomb processing
    private func processBombs() {
        var exploded: Set<UUID> = []
        var didExplode = true

        while didExplode {
            didExplode = false
            let allHands = state.player1.hands + state.player2.hands

            for hand in allHands {
                guard hand.fingerCount == 4, hand.isAlive, !exploded.contains(hand.id) else { continue }
                exploded.insert(hand.id)
                didExplode = true

                // 爆発: この手を殺す
                if let idx = state.player1.handIndex(for: hand.id) {
                    state.player1.hands[idx].fingerCount = 0
                } else if let idx = state.player2.handIndex(for: hand.id) {
                    state.player2.hands[idx].fingerCount = 0
                }
                lastDeadHandId = hand.id
                HapticManager.bombExplosion()

                // 全他の手に+1ダメージ
                let overflowWraps = config.isOverflowWrapEnabled
                for i in state.player1.hands.indices {
                    guard state.player1.hands[i].id != hand.id, state.player1.hands[i].isAlive else { continue }
                    state.player1.hands[i].receiveTap(from: 1, overflowWraps: overflowWraps)
                }
                for i in state.player2.hands.indices {
                    guard state.player2.hands[i].id != hand.id, state.player2.hands[i].isAlive else { continue }
                    state.player2.hands[i].receiveTap(from: 1, overflowWraps: overflowWraps)
                }
            }
        }
    }

    // MARK: - Private
    private func advanceTurn() {
        state.currentPlayerId = (state.currentPlayerId == state.player1.id)
            ? state.player2.id
            : state.player1.id
        state.turnCount += 1
        HapticManager.turnSwitch()

        if isAITurn {
            triggerAITurn()
        }
    }

    @discardableResult
    private func checkWinCondition() -> Bool {
        if state.player1.isDefeated {
            state.phase = .gameOver(winnerId: state.player2.id)
            HapticManager.victory()
            return true
        }
        if state.player2.isDefeated {
            state.phase = .gameOver(winnerId: state.player1.id)
            HapticManager.victory()
            return true
        }
        return false
    }
}
