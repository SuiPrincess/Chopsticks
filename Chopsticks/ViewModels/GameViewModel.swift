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
    /// ヒント: AIが提案する最善手（該当する手が黄色く光る）
    private(set) var hintAction: GameAction?
    private var isComputingHint = false
    var showSplitPanel: Bool = false
    var showRules: Bool = false

    /// newGame()のたびに進む世代番号。前のゲームのAIタスクの誤発火を防ぐ。
    private var gameGeneration = 0
    /// 2人対戦の再戦で先手を交代するためのフラグ
    private var player1StartsNext = true

    // MARK: - Multiplayer
    var multiplayerService: (any MultiplayerService)?
    var localPlayerId: UUID?
    var showDisconnectAlert: Bool = false
    var showRematchRequest: Bool = false
    var isWaitingForRematch: Bool = false
    private var isExecutingRemoteAction: Bool = false

    /// このターン数に達したらサドンデス判定（千日手・膠着対策）
    static let turnLimit = 60

    // MARK: - Computed
    var currentPlayer: Player { state.currentPlayer }
    var opponentPlayer: Player { state.opponentPlayer }
    var isPlayer1Turn: Bool { state.isPlayer1Turn }
    var config: GameConfig { state.config }

    var isGameOver: Bool {
        if case .playing = state.phase { return false }
        return true
    }

    var isDraw: Bool { state.phase == .draw }

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

    var isMultiplayer: Bool {
        config.isMultiplayer
    }

    var isLocalTurn: Bool {
        if !isMultiplayer { return true }
        guard let localId = localPlayerId else { return false }
        return state.currentPlayerId == localId
    }

    var isRemoteControlled: Bool {
        isMultiplayer && !isLocalTurn
    }

    // MARK: - Init
    init(config: GameConfig = GameConfig(), restoring saved: SavedGame? = nil) {
        if let saved {
            self.state = saved.state
            self.attacksThisTurn = saved.attacksThisTurn
        } else {
            self.state = GameState(config: config)
        }
    }

    // MARK: - Multiplayer Setup
    func setupMultiplayer(service: any MultiplayerService) {
        self.multiplayerService = service
        service.onMessageReceived = { [weak self] message in
            self?.handleRemoteMessage(message)
        }
        service.onConnectionChanged = { [weak self] connected in
            if !connected {
                self?.showDisconnectAlert = true
            }
        }
    }

    func startMultiplayerGame(asHost: Bool, opponentName: String) {
        if asHost {
            localPlayerId = state.player1.id
            state.player2 = Player(id: state.player2.id, name: opponentName, handCount: config.handCount)
            multiplayerService?.send(.gameStart(state))
        }
    }

    func handleRemoteMessage(_ message: MultiplayerMessage) {
        switch message {
        case .gameStart(let gameState):
            // ゲストがゲーム状態を受信
            self.state = gameState
            self.localPlayerId = gameState.player2.id
        case .action(let action):
            executeRemoteAction(action)
        case .stateSync(let syncState):
            self.state = syncState
        case .rematchRequest:
            showRematchRequest = true
        case .rematchAccepted:
            isWaitingForRematch = false
            newGame()
            if let service = multiplayerService, service.isHost {
                service.send(.gameStart(state))
            }
        case .disconnect:
            showDisconnectAlert = true
        case .configProposal, .configAccepted:
            break
        }
    }

    func requestRematch() {
        isWaitingForRematch = true
        multiplayerService?.send(.rematchRequest)
    }

    func acceptRematch() {
        showRematchRequest = false
        multiplayerService?.send(.rematchAccepted)
        newGame()
        // ホストが承認した場合もここでゲーム状態を配布しないと、
        // 両端末が別々の盤面（別UUID）で始まってしまい以後の操作が全て無効になる
        if let service = multiplayerService, service.isHost {
            service.send(.gameStart(state))
        }
    }

    func disconnectMultiplayer() {
        multiplayerService?.disconnect()
        multiplayerService = nil
        localPlayerId = nil
    }

    // MARK: - Actions
    func newGame() {
        gameGeneration += 1
        didRankUp = false
        GameSessionStore.shared.clear()
        let previousLocalId = localPlayerId
        var config = state.config
        // ランク戦の再戦は最新レベルのCPUと
        if config.aiLevel != nil {
            config.aiLevel = GameStats.shared.rankLevel
        }
        // 2人対戦の再戦は先手を交代（CPU戦は常に人間が先手）。
        // マルチプレイはホストの状態が正となり、gameStartで配布される。
        if config.gameMode == .localTwoPlayer || (isMultiplayer && multiplayerService?.isHost == true) {
            player1StartsNext.toggle()
        }
        state = GameState(
            config: config,
            player1Starts: config.gameMode == .vsAI || player1StartsNext
        )
        selectedAttackerHandId = nil
        attacksThisTurn = 0
        showSplitPanel = false
        isAIThinking = false
        battleEvent = nil
        hintAction = nil
        isWaitingForRematch = false
        showRematchRequest = false

        // マルチプレイ時はホスト=player1を維持
        if isMultiplayer, let service = multiplayerService {
            if service.isHost {
                localPlayerId = state.player1.id
                state.player2 = Player(id: state.player2.id, name: service.opponentName, handCount: config.handCount)
            } else {
                localPlayerId = previousLocalId
            }
        }
    }

    func selectAttackerHand(_ handId: UUID) {
        guard case .playing = state.phase else { return }
        guard !isAITurn else { return }
        guard !isRemoteControlled else { return }
        guard let hand = currentPlayer.hand(for: handId), hand.isAlive else { return }

        if selectedAttackerHandId == handId {
            selectedAttackerHandId = nil
        } else {
            selectedAttackerHandId = handId
            HapticManager.handSelect()
            SoundManager.play(.select)
        }
    }

    func tapOpponentHand(_ targetHandId: UUID) {
        guard case .playing = state.phase else { return }
        hintAction = nil
        guard let attackerHandId = selectedAttackerHandId else { return }
        guard let attackerHand = currentPlayer.hand(for: attackerHandId), attackerHand.isAlive else { return }
        guard let targetHand = opponentPlayer.hand(for: targetHandId), targetHand.isAlive else { return }

        // マルチプレイ: ローカルアクションを相手に送信
        if isMultiplayer && !isExecutingRemoteAction {
            multiplayerService?.send(.action(.tap(attackerHandId: attackerHandId, targetHandId: targetHandId)))
        }

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
            persistSession()
            if isAITurn { triggerAITurn() }
            return
        }

        attacksThisTurn = 0
        advanceTurn()
    }

    func performSplit(newDistribution: [Int]) {
        guard case .playing = state.phase else { return }
        hintAction = nil
        guard config.isSplittingEnabled else { return }
        guard currentPlayer.isValidSplit(
            newDistribution: newDistribution,
            allowRevival: config.isDeadHandRevivalEnabled
        ) else { return }

        // マルチプレイ: ローカルアクションを相手に送信
        if isMultiplayer && !isExecutingRemoteAction {
            multiplayerService?.send(.action(.split(newDistribution: newDistribution)))
        }

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
        guard !isRemoteControlled else { return }

        if currentPlayer.hand(for: handId) != nil {
            selectAttackerHand(handId)
        } else if opponentPlayer.hand(for: handId) != nil, selectedAttackerHandId != nil {
            tapOpponentHand(handId)
        }
    }

    // MARK: - Remote Action Execution
    private func executeRemoteAction(_ action: GameAction) {
        isExecutingRemoteAction = true
        switch action {
        case .tap(let attackerHandId, let targetHandId):
            selectedAttackerHandId = attackerHandId
            tapOpponentHand(targetHandId)
        case .split(let distribution):
            performSplit(newDistribution: distribution)
        }
        isExecutingRemoteAction = false
    }

    // MARK: - Hint

    /// AI（つよい相当）に最善手を聞き、該当する手を光らせる。
    /// CPU戦の自分の手番でのみ有効。
    func requestHint() {
        guard isVsAI, !isAITurn, case .playing = state.phase,
              hintAction == nil, !isComputingHint
        else { return }
        isComputingHint = true

        let snapshot = state
        let attacksUsed = attacksThisTurn
        let generation = gameGeneration
        let turnCount = state.turnCount

        Task { @MainActor in
            let action = await Task.detached(priority: .userInitiated) {
                AIEngine.chooseAction(
                    state: snapshot,
                    difficulty: .hard,
                    attacksUsedThisTurn: attacksUsed
                )
            }.value
            self.isComputingHint = false
            // 計算中に盤面が動いていたら破棄
            guard generation == self.gameGeneration,
                  self.state.turnCount == turnCount,
                  self.attacksThisTurn == attacksUsed,
                  case .playing = self.state.phase,
                  !self.isAITurn,
                  let action
            else { return }

            self.hintAction = action
            HapticManager.handSelect()
            if case .split = action {
                self.battleEvent = BattleEvent(text: "分割が最善!", color: .yellow)
            }
        }
    }

    // MARK: - AI
    func triggerAITurn() {
        guard isAITurn, case .playing = state.phase, !isAIThinking else { return }
        isAIThinking = true

        let generation = gameGeneration
        let snapshot = state
        let level = config.aiLevel
        let difficulty = config.aiDifficulty
        let attacksUsed = attacksThisTurn

        Task { @MainActor in
            // 探索はメインスレッドを塞がないようバックグラウンドで実行し、
            // 「考えている」演出のため最低600msは待つ
            let clock = ContinuousClock()
            let started = clock.now
            let action = await Task.detached(priority: .userInitiated) { () -> GameAction? in
                if let level {
                    return AIEngine.chooseAction(
                        state: snapshot,
                        level: level,
                        attacksUsedThisTurn: attacksUsed
                    )
                }
                return AIEngine.chooseAction(
                    state: snapshot,
                    difficulty: difficulty,
                    attacksUsedThisTurn: attacksUsed
                )
            }.value
            let elapsed = clock.now - started
            if elapsed < .milliseconds(600) {
                try? await Task.sleep(for: .milliseconds(600) - elapsed)
            }

            guard generation == self.gameGeneration else { return }
            self.isAIThinking = false
            guard self.isAITurn, case .playing = self.state.phase else { return }

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
            SoundManager.play(.split)
        } else if result.poisonTriggered {
            HapticManager.poisonKill()
            SoundManager.play(.poison)
        } else {
            HapticManager.handTap()
            SoundManager.play(.tap)
        }
        if result.bombTriggered {
            HapticManager.bombExplosion()
            SoundManager.play(.boom)
        } else if !result.deadHandIds.isEmpty && !result.poisonTriggered {
            SoundManager.play(.breakHand)
        }
    }

    private func advanceTurn() {
        state.switchTurn()
        hintAction = nil
        HapticManager.turnSwitch()

        if state.turnCount >= Self.turnLimit {
            resolveSuddenDeath()
            return
        }
        if state.turnCount == Self.turnLimit - 10 {
            battleEvent = BattleEvent(text: "あと10ターンで判定!", color: .yellow)
        }

        persistSession()

        if isAITurn {
            triggerAITurn()
        }
    }

    /// 進行中のゲームを自動保存する（アプリ終了・中断からの再開用）
    private func persistSession() {
        guard !isMultiplayer else { return }
        GameSessionStore.shared.save(state: state, attacksThisTurn: attacksThisTurn)
    }

    @discardableResult
    private func checkWinCondition() -> Bool {
        let p1Dead = state.player1.isDefeated
        let p2Dead = state.player2.isDefeated
        guard p1Dead || p2Dead else { return false }

        let winnerId: UUID
        if p1Dead && p2Dead {
            // 相打ち（爆弾連鎖・相討ち毒など）はとどめを刺した手番側の勝ち
            winnerId = state.currentPlayerId
        } else if p1Dead {
            winnerId = state.player2.id
        } else {
            winnerId = state.player1.id
        }
        finishGame(winnerId: winnerId)
        return true
    }

    /// ターン上限到達時の判定: 生きてる手の数 → 指の合計が少ない方 → 引き分け
    private func resolveSuddenDeath() {
        let p1 = state.player1
        let p2 = state.player2
        if p1.aliveHands.count != p2.aliveHands.count {
            finishGame(winnerId: p1.aliveHands.count > p2.aliveHands.count ? p1.id : p2.id)
        } else if p1.totalFingers != p2.totalFingers {
            finishGame(winnerId: p1.totalFingers < p2.totalFingers ? p1.id : p2.id)
        } else {
            finishGame(winnerId: nil)
        }
    }

    /// winnerId == nil は引き分け
    private func finishGame(winnerId: UUID?) {
        if let winnerId {
            state.phase = .gameOver(winnerId: winnerId)
        } else {
            state.phase = .draw
        }
        GameSessionStore.shared.clear()
        HapticManager.victory()
        GameStats.shared.recordDailyPlay()
        if isVsAI, let winnerId {
            let playerWon = winnerId == state.player1.id
            GameStats.shared.recordGame(playerWon: playerWon)
            if playerWon, state.config.aiLevel != nil {
                didRankUp = GameStats.shared.registerRankedWin()
            }
        }
        // リザルトのサウンド（ランクアップ > 勝敗、引き分けは無音）
        if didRankUp {
            SoundManager.play(.rankup)
        } else if let winnerId {
            let humanLostToAI = isVsAI && winnerId == state.player2.id
            SoundManager.play(humanLostToAI ? .lose : .win)
        }
    }
}
