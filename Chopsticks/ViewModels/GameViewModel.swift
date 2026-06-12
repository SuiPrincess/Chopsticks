import SwiftUI

@Observable
@MainActor
final class GameViewModel {
    // MARK: - State
    private(set) var state: GameState
    private(set) var selectedAttackerHandId: UUID?
    private(set) var attacksThisTurn: Int = 0
    private(set) var isAIThinking: Bool = false
    var showSplitPanel: Bool = false
    var showRules: Bool = false

    /// newGame()のたびに進む世代番号。前のゲームのAIタスクの誤発火を防ぐ。
    private var gameGeneration = 0

    // MARK: - Computed
    var currentPlayer: Player { state.currentPlayer }
    var opponentPlayer: Player { state.opponentPlayer }
    var isPlayer1Turn: Bool { state.isPlayer1Turn }
    var config: GameConfig { state.config }

    var isGameOver: Bool {
        if case .gameOver = state.phase { return true }
        return false
    }

    var winnerName: String? {
        guard case .gameOver(let winnerId) = state.phase else { return nil }
        return winnerId == state.player1.id ? state.player1.name : state.player2.name
    }

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
        gameGeneration += 1
        state = GameState(config: state.config)
        selectedAttackerHandId = nil
        attacksThisTurn = 0
        showSplitPanel = false
        isAIThinking = false
    }

    func selectAttackerHand(_ handId: UUID) {
        guard case .playing = state.phase else { return }
        guard !isAITurn else { return }
        guard let hand = currentPlayer.hand(for: handId), hand.isAlive else { return }

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
        guard let attackerHand = currentPlayer.hand(for: attackerHandId), attackerHand.isAlive else { return }
        guard let targetHand = opponentPlayer.hand(for: targetHandId), targetHand.isAlive else { return }

        let result = state.apply(.tap(attackerHandId: attackerHandId, targetHandId: targetHandId))
        playFeedback(for: result, isSplit: false)

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
        guard currentPlayer.isValidSplit(
            newDistribution: newDistribution,
            allowRevival: config.isDeadHandRevivalEnabled
        ) else { return }

        let result = state.apply(.split(newDistribution: newDistribution))
        playFeedback(for: result, isSplit: true)

        showSplitPanel = false
        selectedAttackerHandId = nil
        attacksThisTurn = 0

        // 爆弾ルールでは分割が爆発（→決着）につながることがある
        if checkWinCondition() { return }
        advanceTurn()
    }

    func handleHandTap(_ handId: UUID) {
        guard case .playing = state.phase else { return }
        guard !isAITurn else { return }

        if currentPlayer.hand(for: handId) != nil {
            selectAttackerHand(handId)
        } else if opponentPlayer.hand(for: handId) != nil, selectedAttackerHandId != nil {
            tapOpponentHand(handId)
        }
    }

    // MARK: - AI
    func triggerAITurn() {
        guard isAITurn, case .playing = state.phase, !isAIThinking else { return }
        isAIThinking = true

        let generation = gameGeneration

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard generation == self.gameGeneration else { return }
            self.isAIThinking = false
            guard self.isAITurn, case .playing = self.state.phase else { return }

            guard let action = AIEngine.chooseAction(
                state: self.state,
                difficulty: self.config.aiDifficulty,
                attacksUsedThisTurn: self.attacksThisTurn
            ) else {
                // 行動がなければ手番を返す（通常起こらない）
                self.attacksThisTurn = 0
                self.advanceTurn()
                return
            }
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

    // MARK: - Private
    private func playFeedback(for result: ActionResult, isSplit: Bool) {
        if isSplit {
            HapticManager.split()
        } else if result.poisonTriggered {
            HapticManager.poisonKill()
        } else {
            HapticManager.handTap()
        }
        if result.bombTriggered {
            HapticManager.bombExplosion()
        }
    }

    private func advanceTurn() {
        state.switchTurn()
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
