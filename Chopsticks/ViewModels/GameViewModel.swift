import SwiftUI

/// 画面中央に一瞬表示する戦闘イベントバナー
struct BattleEvent: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let color: Color
}

/// マルチプレイ中に1つのアラートで出す通知
enum MultiplayerNotice: Identifiable, Equatable {
    case connectionLost
    case opponentLeft
    case rematchDeclined
    case rematchTimedOut
    case movedToBackground

    var id: String { title }

    var title: String {
        switch self {
        case .connectionLost: "接続が切れました"
        case .opponentLeft: "相手が退出しました"
        case .rematchDeclined: "リマッチは断られました"
        case .rematchTimedOut: "相手から返事がありません"
        case .movedToBackground: "対戦が終了しました"
        }
    }

    var message: String {
        switch self {
        case .connectionLost: "通信が途切れたため対戦を続けられません。"
        case .opponentLeft: "相手が対戦を終了しました。"
        case .rematchDeclined: "相手は別の対戦へ向かったようです。"
        case .rematchTimedOut: "しばらく待ちましたが応答がありませんでした。"
        case .movedToBackground: "アプリがバックグラウンドに移動したため、対戦が終了しました。"
        }
    }
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
    /// 今回のゲームで得た報酬（XP・レベルアップ等）。ゲーム終了時に設定される。
    private(set) var rewards: GameRewards?
    /// 今回のゲームで解除した実績
    private(set) var unlockedAchievements: [Achievement] = []
    /// 終了したゲームの要約（共有文などに使う）
    private(set) var lastSummary: GameSummary?
    /// 連戦スコア（2人対戦・マルチプレイで再戦を重ねたときの通算）
    private(set) var sessionScore: (player1: Int, player2: Int) = (0, 0)
    var showSplitPanel: Bool = false
    var showRules: Bool = false

    /// newGame()のたびに進む世代番号。前のゲームのAIタスクの誤発火を防ぐ。
    private var gameGeneration = 0
    /// 2人対戦・マルチプレイの再戦で先手を交代するためのフラグ
    private var player1StartsNext = true
    /// 自分（Player 1）が「残り片手」の状態を経験したか（大逆転の判定）
    private var player1WasDownToOneHand = false
    private var aiTask: Task<Void, Never>?
    private var isExecutingAIAction = false
    /// テスト用: CPU・相手の手を見せるための待ち時間を省略する
    var skipsPacingDelays = false

    // MARK: - Multiplayer
    var multiplayerService: (any MultiplayerService)?
    var localPlayerId: UUID?
    var showRematchRequest: Bool = false
    var isWaitingForRematch: Bool = false
    /// ゲストがホストからの`gameStart`を待っている間true
    private(set) var isWaitingForHost: Bool = false
    /// 相手との接続が失われた（リマッチ不可）
    private(set) var isConnectionLost: Bool = false
    var notice: MultiplayerNotice?
    private var isExecutingRemoteAction: Bool = false
    private var opponentRequestedRematch = false
    /// 相手の方が先に決着画面に着いて、こちらの決着前に届いたリマッチ要求
    private var deferredRematchRequest = false
    /// 一度切断したら、同じ画面から再接続しない（onAppearの再呼び出し対策）
    private var hasDisconnected = false
    private var remoteActionQueue: [GameAction] = []
    private var isProcessingRemoteActions = false
    private var rematchTimeoutTask: Task<Void, Never>?

    /// このターン数に達したらサドンデス判定（千日手・膠着対策）
    static let turnLimit = GameState.turnLimit

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

    /// 「自分」。CPU戦・マルチプレイではPlayer 1/ローカルプレイヤー、1台2人対戦ではnil。
    var localPlayer: Player? {
        if isMultiplayer {
            guard let localId = localPlayerId else { return nil }
            return localId == state.player1.id ? state.player1 : state.player2
        }
        return isVsAI ? state.player1 : nil
    }

    /// 画面下に描く（手前の）プレイヤー。マルチプレイのゲストでも自分が下。
    var bottomPlayer: Player { localPlayer ?? state.player1 }
    var topPlayer: Player { bottomPlayer.id == state.player1.id ? state.player2 : state.player1 }
    var isBottomPlayerTurn: Bool { state.currentPlayerId == bottomPlayer.id }

    /// 自分（ローカルプレイヤー）が勝ったか。1台2人対戦ではnil。
    var didLocalPlayerWin: Bool? {
        guard let local = localPlayer, let winner else { return nil }
        return winner.id == local.id
    }

    var isLocalTurn: Bool {
        if !isMultiplayer { return true }
        guard let localId = localPlayerId else { return false }
        return state.currentPlayerId == localId
    }

    var isRemoteControlled: Bool {
        isMultiplayer && !isLocalTurn
    }

    /// 人間（この端末のユーザー）が今操作できるか
    var isHumanTurn: Bool {
        !isGameOver && !isAITurn && !isRemoteControlled && !isWaitingForHost
    }

    /// 残りターン数（サドンデス判定まで）
    var turnsRemaining: Int { max(0, Self.turnLimit - state.turnCount) }

    /// 次の相手の攻撃で死にうる手（ルールに基づく。赤い警告表示に使う）
    var threatenedHandIds: Set<UUID> {
        guard case .playing = state.phase else { return [] }
        let hands = state.player1.aliveHands + state.player2.aliveHands
        return Set(hands.filter { state.isHandThreatened($0.id) }.map(\.id))
    }

    /// 現在の手番プレイヤーに有効な分割があるか
    var canSplitNow: Bool {
        config.isSplittingEnabled && currentPlayer.hasValidSplit(allowRevival: config.isDeadHandRevivalEnabled)
    }

    // MARK: - Init
    init(config: GameConfig = GameConfig()) {
        self.state = GameState(config: config)
    }

    /// 中断していたゲームを再開する
    init(savedGame: SavedGame) {
        self.state = savedGame.state
        self.attacksThisTurn = savedGame.attacksThisTurn
        self.player1WasDownToOneHand = savedGame.state.player1.hands.count >= 2 && savedGame.state.player1.aliveHands.count == 1
    }

    /// 画面表示時に呼ぶ。再開したゲームがCPUの手番なら思考を始める。
    func onAppear() {
        if isAITurn { triggerAITurn() }
    }

    /// 画面を離れるとき（AIタスクの停止）
    func onDisappear() {
        gameGeneration += 1
        aiTask?.cancel()
        aiTask = nil
        isAIThinking = false
        rematchTimeoutTask?.cancel()
    }

    // MARK: - Multiplayer Setup
    func setupMultiplayer(service: any MultiplayerService) {
        guard multiplayerService == nil, !hasDisconnected else { return }
        self.multiplayerService = service
        service.onConnectionChanged = { [weak self] connected in
            if !connected {
                self?.handleConnectionLost(.connectionLost)
            }
        }
        if service.isHost {
            localPlayerId = state.player1.id
            state.player1 = renamed(state.player1, to: "あなた")
            state.player2 = Player(id: state.player2.id, name: service.opponentName, handCount: config.handCount)
            service.send(.gameStart(state))
            showRules = true
        } else {
            isWaitingForHost = true
        }
        // ハンドラ設定時に、画面表示前に届いていたメッセージ（gameStart等）がまとめて配送される
        service.onMessageReceived = { [weak self] message in
            self?.handleRemoteMessage(message)
        }
        if !service.isConnected {
            handleConnectionLost(.connectionLost)
        }
    }

    func handleRemoteMessage(_ message: MultiplayerMessage) {
        switch message {
        case .gameStart(let gameState):
            // ゲストがゲーム状態を受信。進行中のゲームを重複gameStartで壊さない。
            guard let service = multiplayerService, !service.isHost else { return }
            guard isWaitingForHost || isGameOver else { return }
            gameGeneration += 1
            var received = gameState
            received.player1 = renamed(gameState.player1, to: service.opponentName)
            received.player2 = renamed(gameState.player2, to: "あなた")
            state = received
            localPlayerId = gameState.player2.id
            resetTransientState()
            remoteActionQueue = []
            isWaitingForHost = false
            isWaitingForRematch = false
            showRematchRequest = false
            opponentRequestedRematch = false
            rematchTimeoutTask?.cancel()
            showRules = true
        case .action(let action):
            enqueueRemoteAction(action)
        case .rematchRequest:
            guard !isConnectionLost else { return }
            guard isGameOver else {
                // 相手の方が先に決着画面に着いた: こちらの決着が出てから通知する
                deferredRematchRequest = true
                return
            }
            if isWaitingForRematch {
                // 両者が同時にリマッチを要求した: 承認扱い（ホストだけが承認を返す）
                opponentRequestedRematch = true
                acceptRematch(sendAccept: multiplayerService?.isHost == true)
            } else {
                opponentRequestedRematch = true
                showRematchRequest = true
            }
        case .rematchAccepted:
            guard isWaitingForRematch else { return }
            isWaitingForRematch = false
            rematchTimeoutTask?.cancel()
            startRematch()
        case .rematchDeclined:
            isWaitingForRematch = false
            rematchTimeoutTask?.cancel()
            handleConnectionLost(.rematchDeclined)
        case .playerLeft:
            handleConnectionLost(.opponentLeft)
        case .disconnect:
            handleConnectionLost(.connectionLost)
        case .stateSync, .configProposal, .configAccepted:
            // 現在は使っていない（ホストが開始時に盤面を配り、以降は操作を送り合う）
            break
        }
    }

    private func handleConnectionLost(_ reason: MultiplayerNotice) {
        guard !isConnectionLost else { return }
        isConnectionLost = true
        deferredRematchRequest = false
        isWaitingForRematch = false
        isWaitingForHost = false
        showRematchRequest = false
        rematchTimeoutTask?.cancel()
        notice = reason
    }

    func requestRematch() {
        guard !isConnectionLost else { return }
        if opponentRequestedRematch {
            acceptRematch()
            return
        }
        isWaitingForRematch = true
        multiplayerService?.send(.rematchRequest)
        rematchTimeoutTask?.cancel()
        rematchTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(25))
            guard let self, !Task.isCancelled, self.isWaitingForRematch else { return }
            self.isWaitingForRematch = false
            self.notice = .rematchTimedOut
        }
    }

    func cancelRematchRequest() {
        isWaitingForRematch = false
        rematchTimeoutTask?.cancel()
    }

    func acceptRematch(sendAccept: Bool = true) {
        showRematchRequest = false
        opponentRequestedRematch = false
        isWaitingForRematch = false
        rematchTimeoutTask?.cancel()
        if sendAccept {
            multiplayerService?.send(.rematchAccepted)
        }
        startRematch()
    }

    func declineRematch() {
        showRematchRequest = false
        opponentRequestedRematch = false
        multiplayerService?.send(.rematchDeclined)
    }

    /// ホストは新しい盤面を作って配布、ゲストはホストの`gameStart`を待つ
    private func startRematch() {
        guard let service = multiplayerService else { return }
        if service.isHost {
            newGame()
            service.send(.gameStart(state))
        } else {
            isWaitingForHost = true
            // 古い要求を承認した場合など、ホストが新しい盤面を配ってこないときは諦める
            rematchTimeoutTask?.cancel()
            let generation = gameGeneration
            rematchTimeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(15))
                guard let self, !Task.isCancelled, generation == self.gameGeneration,
                      self.isWaitingForHost, self.isGameOver else { return }
                self.isWaitingForHost = false
                self.notice = .rematchTimedOut
            }
        }
    }

    /// 自分から対戦を離れる（相手には「退出」と伝える）
    func leaveMultiplayer() {
        multiplayerService?.send(.playerLeft)
        disconnectMultiplayer()
    }

    func disconnectMultiplayer() {
        multiplayerService?.disconnect()
        multiplayerService = nil
        // localPlayerIdは消さない（消すと結果画面が「自分の勝ち敗け」を判定できず、盤面の上下も入れ替わる）
        hasDisconnected = true
    }

    /// バックグラウンドに移動した: 通信セッションは維持できないので対戦を終了する
    func handleAppBackgrounded() {
        guard isMultiplayer, !isConnectionLost else { return }
        multiplayerService?.send(.playerLeft)
        multiplayerService?.disconnect()
        handleConnectionLost(.movedToBackground)
    }

    private func renamed(_ player: Player, to name: String) -> Player {
        var p = Player(id: player.id, name: name, handCount: player.hands.count)
        p.hands = player.hands
        return p
    }

    // MARK: - Actions
    func newGame() {
        gameGeneration += 1
        aiTask?.cancel()
        didRankUp = false
        rewards = nil
        unlockedAchievements = []
        lastSummary = nil
        player1WasDownToOneHand = false
        let previousLocalId = localPlayerId
        var config = state.config
        // ランク戦の再戦は最新レベルのCPUと
        if config.isRanked {
            config.aiLevel = GameStats.shared.rankLevel
        }
        // 2人対戦・マルチプレイの再戦は先手を交代（CPU戦は常に人間が先手）
        if config.gameMode == .localTwoPlayer || config.isMultiplayer {
            player1StartsNext.toggle()
        }
        state = GameState(
            config: config,
            player1Starts: config.gameMode == .vsAI || player1StartsNext
        )
        resetTransientState()
        isWaitingForRematch = false
        showRematchRequest = false
        opponentRequestedRematch = false
        remoteActionQueue = []
        deferredRematchRequest = false

        // マルチプレイ時はホスト=player1を維持
        if isMultiplayer, let service = multiplayerService {
            if service.isHost {
                localPlayerId = state.player1.id
                state.player1 = renamed(state.player1, to: "あなた")
                state.player2 = Player(id: state.player2.id, name: service.opponentName, handCount: config.handCount)
            } else {
                localPlayerId = previousLocalId
            }
        }
        persistSession()
    }

    private func resetTransientState() {
        selectedAttackerHandId = nil
        attacksThisTurn = 0
        showSplitPanel = false
        isAIThinking = false
        battleEvent = nil
    }

    func selectAttackerHand(_ handId: UUID) {
        guard case .playing = state.phase else { return }
        guard isHumanTurn else { return }
        guard let hand = currentPlayer.hand(for: handId), hand.isAlive else { return }

        if selectedAttackerHandId == handId {
            selectedAttackerHandId = nil
        } else {
            selectedAttackerHandId = handId
            HapticManager.handSelect()
            SoundManager.shared.play(.select)
        }
    }

    /// 今アクションを適用してよい主体か（人間の手番、またはAI/リモートの実行中）
    private var canApplyActionNow: Bool {
        if isAITurn { return isExecutingAIAction }
        if isRemoteControlled { return isExecutingRemoteAction }
        return !isWaitingForHost
    }

    func tapOpponentHand(_ targetHandId: UUID) {
        guard case .playing = state.phase else { return }
        guard canApplyActionNow else { return }
        guard let attackerHandId = selectedAttackerHandId else { return }
        guard let attackerHand = currentPlayer.hand(for: attackerHandId), attackerHand.isAlive else { return }
        guard let targetHand = opponentPlayer.hand(for: targetHandId), targetHand.isAlive else { return }

        // マルチプレイ: ローカルアクションを相手に送信
        if isMultiplayer && !isExecutingRemoteAction {
            multiplayerService?.send(.action(.tap(attackerHandId: attackerHandId, targetHandId: targetHandId)))
        }

        let result = state.apply(.tap(attackerHandId: attackerHandId, targetHandId: targetHandId))
        playFeedback(for: result, isSplit: false, isLocalActor: !isExecutingAIAction && !isExecutingRemoteAction)
        let announced = announce(result)

        selectedAttackerHandId = nil

        if checkWinCondition() { return }
        trackComeback()

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
        guard canApplyActionNow else { return }
        guard config.isSplittingEnabled else { return }
        guard currentPlayer.isValidSplit(
            newDistribution: newDistribution,
            allowRevival: config.isDeadHandRevivalEnabled
        ) else { return }

        // マルチプレイ: ローカルアクションを相手に送信
        if isMultiplayer && !isExecutingRemoteAction {
            multiplayerService?.send(.action(.split(newDistribution: newDistribution)))
        }

        let isLocalActor = !isExecutingAIAction && !isExecutingRemoteAction
        let actorName = currentPlayer.name
        let result = state.apply(.split(newDistribution: newDistribution))
        playFeedback(for: result, isSplit: true, isLocalActor: isLocalActor)
        if !announce(result) && !isLocalActor {
            battleEvent = BattleEvent(text: "\(actorName)が分割", color: .cyan)
        }

        showSplitPanel = false
        selectedAttackerHandId = nil
        attacksThisTurn = 0

        // 爆弾ルールでは分割が爆発（→決着）につながることがある
        if checkWinCondition() { return }
        trackComeback()
        advanceTurn()
    }

    func handleHandTap(_ handId: UUID) {
        guard case .playing = state.phase else { return }
        guard isHumanTurn else { return }

        if currentPlayer.hand(for: handId) != nil {
            selectAttackerHand(handId)
        } else if opponentPlayer.hand(for: handId) != nil, selectedAttackerHandId != nil {
            tapOpponentHand(handId)
        }
    }

    // MARK: - 中断・再開

    /// 「あとで続きから」: 保存したまま画面を閉じる
    func suspendGame() {
        persistSession()
        onDisappear()
    }

    /// 「対戦を破棄」: 保存を消して画面を閉じる。進行中のランク戦は負け扱い。
    func abandonGame() {
        onDisappear()
        GameSessionStore.clear()
        if config.isRanked, !isGameOver, state.turnCount > 0 {
            GameStats.shared.recordAbandonedRankedGame()
        }
    }

    private func persistSession() {
        // 1手も指していない対戦は保存しない（「続きから」に空の対戦が出ない・前の中断対戦を上書きしない）
        guard !isMultiplayer, state.turnCount > 0 || attacksThisTurn > 0 else { return }
        GameSessionStore.save(state: state, attacksThisTurn: attacksThisTurn)
    }

    // MARK: - Remote Action Execution
    private func enqueueRemoteAction(_ action: GameAction) {
        remoteActionQueue.append(action)
        processRemoteActionsIfNeeded()
    }

    private func processRemoteActionsIfNeeded() {
        guard !isProcessingRemoteActions, !remoteActionQueue.isEmpty else { return }
        isProcessingRemoteActions = true
        let action = remoteActionQueue.removeFirst()
        let generation = gameGeneration
        Task { @MainActor in
            // 相手がどの手で攻撃したか見えるよう、少し間を置いてから適用する
            if case .tap(let attackerHandId, _) = action, self.isRemoteControlled {
                self.selectedAttackerHandId = attackerHandId
                if !self.skipsPacingDelays {
                    try? await Task.sleep(for: .milliseconds(350))
                }
            }
            if generation == self.gameGeneration, self.isRemoteControlled {
                self.isExecutingRemoteAction = true
                switch action {
                case .tap(let attackerHandId, let targetHandId):
                    self.selectedAttackerHandId = attackerHandId
                    self.tapOpponentHand(targetHandId)
                case .split(let distribution):
                    self.performSplit(newDistribution: distribution)
                }
                self.isExecutingRemoteAction = false
            }
            self.isProcessingRemoteActions = false
            self.processRemoteActionsIfNeeded()
        }
    }

    // MARK: - AI
    func triggerAITurn() {
        guard isAITurn, case .playing = state.phase, !isAIThinking else { return }
        isAIThinking = true

        let generation = gameGeneration
        let snapshot = state
        let attacksUsed = attacksThisTurn
        let level = config.aiLevel
        let difficulty = config.aiDifficulty
        let mercy = config.isRanked ? GameStats.shared.mercyBoost : 0

        aiTask?.cancel()
        aiTask = Task { @MainActor in
            let started = ContinuousClock.now
            // 探索はメインスレッドを塞がないようバックグラウンドで実行する
            let action = await Task.detached(priority: .userInitiated) { () -> GameAction? in
                if let level {
                    return AIEngine.chooseAction(state: snapshot, level: level, attacksUsedThisTurn: attacksUsed, mercyBoost: mercy)
                }
                return AIEngine.chooseAction(state: snapshot, difficulty: difficulty, attacksUsedThisTurn: attacksUsed)
            }.value
            // 「考えている」感を出すため最低限の間を置く
            let elapsed = ContinuousClock.now - started
            let minimumThinkTime: Duration = self.skipsPacingDelays ? .zero : .milliseconds(650)
            if elapsed < minimumThinkTime {
                try? await Task.sleep(for: minimumThinkTime - elapsed)
            }

            guard !Task.isCancelled, generation == self.gameGeneration else { return }
            guard self.isAITurn, case .playing = self.state.phase else {
                self.isAIThinking = false
                return
            }

            guard let action else {
                // 行動がなければ手番を返す（通常起こらない）
                self.isAIThinking = false
                self.attacksThisTurn = 0
                self.advanceTurn()
                return
            }

            // どの手で攻撃するか先に見せる
            if case .tap(let attackerHandId, _) = action {
                self.selectedAttackerHandId = attackerHandId
                if !self.skipsPacingDelays {
                    try? await Task.sleep(for: .milliseconds(380))
                }
                guard !Task.isCancelled, generation == self.gameGeneration else { return }
            }
            self.isAIThinking = false
            self.executeAIAction(action)
        }
    }

    private func executeAIAction(_ action: GameAction) {
        isExecutingAIAction = true
        defer { isExecutingAIAction = false }
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

    private func playFeedback(for result: ActionResult, isSplit: Bool, isLocalActor: Bool) {
        if isSplit {
            if isLocalActor { HapticManager.split() }
            SoundManager.shared.play(.split)
        } else if result.poisonTriggered {
            HapticManager.poisonKill()
            SoundManager.shared.play(.poison)
        } else {
            if isLocalActor { HapticManager.handTap() }
            SoundManager.shared.play(.tap)
        }
        if result.bombTriggered {
            HapticManager.bombExplosion()
            SoundManager.shared.play(.bomb)
        } else if !result.deadHandIds.isEmpty && !result.poisonTriggered {
            SoundManager.shared.play(.breakHand)
        }
    }

    private func trackComeback() {
        let hands = state.player1.hands
        if hands.count >= 2 && state.player1.aliveHands.count == 1 {
            player1WasDownToOneHand = true
        }
    }

    private func advanceTurn() {
        state.switchTurn()
        HapticManager.turnSwitch()

        if state.turnCount >= Self.turnLimit {
            resolveSuddenDeath()
            return
        }
        if state.turnCount == Self.turnLimit - 10 {
            battleEvent = BattleEvent(text: "残り10ターン!", color: .yellow)
            SoundManager.shared.play(.turnWarning)
        }

        persistSession()

        if isAITurn {
            triggerAITurn()
        }
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
        finishGame(winnerId: winnerId, bySuddenDeath: false)
        return true
    }

    /// ターン上限到達時の判定: 生きてる手の数 → 指の合計が少ない方 → 引き分け
    private func resolveSuddenDeath() {
        switch state.suddenDeathOutcome() {
        case .winner(let id): finishGame(winnerId: id, bySuddenDeath: true)
        case .draw: finishGame(winnerId: nil, bySuddenDeath: true)
        }
    }

    /// winnerId == nil は引き分け
    private func finishGame(winnerId: UUID?, bySuddenDeath: Bool) {
        if let winnerId {
            state.phase = .gameOver(winnerId: winnerId)
            if winnerId == state.player1.id { sessionScore.player1 += 1 } else { sessionScore.player2 += 1 }
        } else {
            state.phase = .draw
        }
        selectedAttackerHandId = nil
        showSplitPanel = false
        aiTask?.cancel()
        isAIThinking = false
        GameSessionStore.clear()

        // 結果の要約
        let outcome: GameSummary.Outcome
        if let local = localPlayer {
            if let winnerId {
                outcome = winnerId == local.id ? .win : .loss
            } else {
                outcome = .draw
            }
        } else {
            outcome = winnerId == nil ? .draw : .completed
        }
        let localWon = outcome == .win
        // 決着した手を含めた「遊んだターン数」（画面のターン表示と同じ数え方）
        let turnsPlayed = bySuddenDeath ? state.turnCount : state.turnCount + 1
        let summary = GameSummary(
            mode: config.gameMode,
            outcome: outcome,
            turnCount: turnsPlayed,
            config: config,
            isPerfect: localWon && isPerfectWin,
            isComeback: localWon && player1WasDownToOneHand && isVsAI,
            decidedBySuddenDeath: bySuddenDeath
        )
        lastSummary = summary

        // 演出
        switch outcome {
        case .win, .completed:
            HapticManager.victory()
            SoundManager.shared.play(.win)
        case .loss:
            HapticManager.defeat()
            SoundManager.shared.play(.lose)
        case .draw:
            HapticManager.turnSwitch()
            SoundManager.shared.play(.draw)
        }

        // 戦績・XP・実績
        let stats = GameStats.shared
        let levelBefore = stats.playerLevel
        let titleBefore = stats.playerTitle
        var gameRewards = stats.record(summary)
        didRankUp = gameRewards.rankedUp

        // 実績のXPで次の実績（レベル到達など）の条件が揃うことがあるので、新しい解除がなくなるまで繰り返す
        var unlocked = AchievementStore.shared.evaluate(summary: summary, stats: stats)
        var batch = unlocked
        while !batch.isEmpty {
            for achievement in batch {
                stats.addXP(achievement.xpReward)
                gameRewards.xpGained += achievement.xpReward
            }
            batch = AchievementStore.shared.evaluate(summary: nil, stats: stats)
            unlocked += batch
        }
        if stats.playerLevel > levelBefore {
            gameRewards.leveledUp = true
            if stats.playerTitle != titleBefore { gameRewards.newTitle = stats.playerTitle }
        }
        rewards = gameRewards
        unlockedAchievements = unlocked
        GameCenterManager.shared.report(achievements: unlocked)
        GameCenterManager.shared.submitScores(stats: stats)

        // 決着前に相手のリマッチ要求が届いていたら、ここで通知する
        if deferredRematchRequest && isMultiplayer && !isConnectionLost {
            deferredRematchRequest = false
            opponentRequestedRematch = true
            showRematchRequest = true
        }
    }
}
