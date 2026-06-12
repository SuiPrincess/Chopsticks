import SwiftUI

/// 画面中央に一瞬表示する戦闘イベントバナー
struct BattleEvent: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let color: Color
}

@Observable
@MainActor
final class GameViewModel {
    // MARK: - State
    private(set) var state: GameState
    private(set) var selectedAttackerHandId: UUID?
    private(set) var attacksThisTurn: Int = 0
    private(set) var isAIThinking: Bool = false
    /// 直近の戦闘イベント（バナー表示用）
    private(set) var battleEvent: BattleEvent?
    /// 手が死ぬたびに進むカウンタ。画面シェイクのトリガー。
    private(set) var shakeTrigger = 0
    /// この勝利でランクが上がったか（リザルト演出用）
    private(set) var didRankUp = false
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

    var winner: Player? {
        guard case .gameOver(let winnerId) = state.phase else { return nil }
        return winnerId == state.player1.id ? state.player1 : state.player2
    }

    var winnerName: String? { winner?.name }

    /// 勝者が一本も手を失わずに勝ったか
    var isPerfectWin: Bool {
        guard let winner else { return false }
        return winner.hands.allSatisfy(\.isAlive)
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
        didRankUp = false
        var config = state.config
        // ランク戦の再戦は最新レベルのCPUと
        if config.aiLevel != nil {
            config.aiLevel = GameStats.shared.rankLevel
        }
        state = GameState(config: config)
        selectedAttackerHandId = nil
        attacksThisTurn = 0
        showSplitPanel = false
        isAIThinking = false
        battleEvent = nil
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
        let announced = announce(result)

        selectedAttackerHandId = nil

        if checkWinCondition() { return }

        // ダブルタップ: 1ターンに2回攻撃
        if config.isDoubleTapEnabled && attacksThisTurn == 0 {
            attacksThisTurn = 1
            if !announced {
                battleEvent = BattleEvent(text: "もう1回!", color: .purple)
            }
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
        announce(result)

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

            let action: GameAction?
            if let level = self.config.aiLevel {
                action = AIEngine.chooseAction(
                    state: self.state,
                    level: level,
                    attacksUsedThisTurn: self.attacksThisTurn
                )
            } else {
                action = AIEngine.chooseAction(
                    state: self.state,
                    difficulty: self.config.aiDifficulty,
                    attacksUsedThisTurn: self.attacksThisTurn
                )
            }
            guard let action else {
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

    /// 派手な結果をバナーとシェイクで演出する。何か表示したらtrue。
    @discardableResult
    private func announce(_ result: ActionResult) -> Bool {
        if !result.deadHandIds.isEmpty {
            shakeTrigger += 1
        }
        if result.bombTriggered {
            battleEvent = BattleEvent(text: "BOOM!", color: .orange)
        } else if result.poisonTriggered {
            battleEvent = BattleEvent(text: "POISON!", color: .green)
        } else if !result.deadHandIds.isEmpty {
            battleEvent = BattleEvent(text: "BREAK!", color: .red)
        } else {
            return false
        }
        return true
    }

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
        let winnerId: UUID
        if state.player1.isDefeated {
            winnerId = state.player2.id
        } else if state.player2.isDefeated {
            winnerId = state.player1.id
        } else {
            return false
        }

        state.phase = .gameOver(winnerId: winnerId)
        HapticManager.victory()
        GameStats.shared.recordDailyPlay()
        if isVsAI {
            let playerWon = winnerId == state.player1.id
            GameStats.shared.recordGame(playerWon: playerWon)
            if playerWon, state.config.aiLevel != nil {
                didRankUp = GameStats.shared.registerRankedWin()
            }
        }
        return true
    }
}
