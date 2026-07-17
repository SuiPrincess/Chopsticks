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
    /// この勝利で報酬テーマが解放されたか（リザルト演出用）
    private(set) var unlockedRewardTheme: Theme?
    /// 直前のゲームのリプレイ（リザルトの「リプレイを見る」用）
    private(set) var lastReplay: Replay?
    private var actionLog: [GameAction] = []
    private var replayInitialState: GameState
    /// リプレイ記録開始時点のattacksThisTurn（ダブルタップ途中の再開でも再生を一致させる）
    private var replayInitialAttacks = 0
    /// ヒント: AIが提案する最善手（該当する手が黄色く光る）
    private(set) var hintAction: GameAction?
    private var isComputingHint = false
    /// 無料枠のヒントを使い切った（GameViewがショップ導線付きアラートを出す）
    var hintLimitReached = false
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
    /// 切断アラートの見出し（リマッチ拒否は「相手が退出しました」になる）
    var disconnectMessage: String = String(localized: "接続が切れました")
    var showRematchRequest: Bool = false
    var isWaitingForRematch: Bool = false
    private var isExecutingRemoteAction: Bool = false

    /// このターン数に達したらサドンデス判定（千日手・膠着対策）
    static let turnLimit = GameRules.turnLimit

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

    /// マルチプレイのゲスト（=player2）視点か。
    /// trueなら画面の手前（下側）に自分＝player2を表示する。
    var isGuestPerspective: Bool {
        isMultiplayer && localPlayerId == state.player2.id
    }

    // MARK: - Init
    init(config: GameConfig = GameConfig(), restoring saved: SavedGame? = nil) {
        // @Observableのプロパティは全初期化完了までselfから読めないため、
        // ローカル値を組み立ててから各プロパティに代入する
        let initialState = saved?.state ?? GameState(config: config)
        let initialAttacks = saved?.attacksThisTurn ?? 0
        self.state = initialState
        self.attacksThisTurn = initialAttacks
        // 復元ゲームのリプレイは再開地点から記録する
        self.replayInitialState = initialState
        self.replayInitialAttacks = initialAttacks
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
        // 接続〜この画面表示までの間に切断されていた場合、
        // イベントは既に流れてしまっているのでここで検知する
        if !service.isConnected {
            showDisconnectAlert = true
        }
    }

    func startMultiplayerGame(asHost: Bool, opponentName: String, localName: String) {
        // onAppearの再発火などで二重初期化して対局をリセットしないよう冪等にする
        guard asHost, localPlayerId == nil else { return }
        localPlayerId = state.player1.id
        state.player1 = Player(id: state.player1.id, name: localName, handCount: config.handCount)
        state.player2 = Player(id: state.player2.id, name: opponentName, handCount: config.handCount)
        replayInitialState = state
        replayInitialAttacks = 0
        actionLog = []
        multiplayerService?.send(.gameStart(state))
    }

    func handleRemoteMessage(_ message: MultiplayerMessage) {
        switch message {
        case .gameStart(let gameState):
            // ゲストがゲーム状態を受信。前ゲームがダブルタップの2撃目で決着していると
            // attacksThisTurnが1のまま残り、ホスト（newGameで0リセット）とズレるため必ず戻す
            self.state = gameState
            self.localPlayerId = gameState.player2.id
            self.attacksThisTurn = 0
            self.replayInitialState = gameState
            self.replayInitialAttacks = 0
            self.actionLog = []
        case .action(let action):
            executeRemoteAction(action)
        case .stateSync(let syncState):
            // 注意: stateSyncはattacksThisTurnを運ばない。現状送信側は存在しないが、
            // 将来実装するならダブルタップ途中の同期でローカル値とズレる点に留意
            self.state = syncState
            self.replayInitialState = syncState
            self.replayInitialAttacks = attacksThisTurn
            self.actionLog = []
        case .rematchRequest:
            showRematchRequest = true
        case .rematchAccepted:
            // 自分が要求した場合のみ処理する。同時リマッチで双方が承認すると
            // .rematchAcceptedが交差するが、承認側はnewGame()済み
            //（isWaitingForRematch=false）なので二重に開始しない
            guard isWaitingForRematch else { break }
            isWaitingForRematch = false
            newGame()
            if let service = multiplayerService, service.isHost {
                service.send(.gameStart(state))
            }
        case .rematchDeclined:
            isWaitingForRematch = false
            disconnectMessage = String(localized: "相手が退出しました")
            showDisconnectAlert = true
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

    /// リマッチ拒否メッセージの送信を待っている間、即時切断を抑止するフラグ
    private var isDecliningRematch = false

    /// リマッチ要求を断って退出する（相手には「相手が退出しました」と伝わる）
    func declineRematch() {
        showRematchRequest = false
        multiplayerService?.send(.rematchDeclined)
        // 即座にdisconnectすると送信キューのメッセージが落ちることがあるため、
        // 少し待ってから切断する。この間の画面遷移由来のdisconnectは抑止する。
        isDecliningRematch = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            self.isDecliningRematch = false
            self.disconnectMultiplayer()
        }
    }

    func disconnectMultiplayer() {
        // declineRematch()の遅延切断に任せる（送信キューのフラッシュ待ち）
        guard !isDecliningRematch else { return }
        multiplayerService?.disconnect()
        multiplayerService = nil
        localPlayerId = nil
    }

    /// ゲームを途中で放棄する。進行中のAI思考タスクの結果を無効化し、
    /// 退出後に敗北が記録されたりセーブが消えたりするのを防ぐ。
    func abandonGame() {
        gameGeneration += 1
        isAIThinking = false
    }

    /// 「やめる」時に自動保存が残るか（保存条件と一致させる）
    var hasSavableProgress: Bool {
        guard case .playing = state.phase else { return false }
        return !isMultiplayer && (state.turnCount > 0 || attacksThisTurn > 0)
    }

    // MARK: - Actions
    func newGame() {
        gameGeneration += 1
        didRankUp = false
        unlockedRewardTheme = nil
        lastReplay = nil
        actionLog = []
        // マルチプレイのリマッチが、無関係なシングルプレイの中断セーブを
        // 消してしまわないようガードする
        if !isMultiplayer {
            GameSessionStore.shared.clear()
        }
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
                state.player1 = Player(id: state.player1.id, name: service.localPlayerName, handCount: config.handCount)
                state.player2 = Player(id: state.player2.id, name: service.opponentName, handCount: config.handCount)
            } else {
                localPlayerId = previousLocalId
            }
        }

        // リプレイの記録開始位置を新しい盤面に合わせる（プレイヤー名再設定の後）
        replayInitialState = state
        replayInitialAttacks = 0
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
        actionLog.append(.tap(attackerHandId: attackerHandId, targetHandId: targetHandId))
        playFeedback(for: result, isSplit: false)
        let announced = announce(result)

        selectedAttackerHandId = nil

        if checkWinCondition() { return }

        // ダブルタップ: 1ターンに2回攻撃
        if config.isDoubleTapEnabled && attacksThisTurn == 0 {
            attacksThisTurn = 1
            if !announced {
                battleEvent = BattleEvent(text: String(localized: "もう1回!"), color: .purple)
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
        // 相手の手番中にこちらから相手の分割を実行できてはいけない
        //（リモートから受信した正規のアクションは通す）
        guard !isRemoteControlled || isExecutingRemoteAction else { return }
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
        actionLog.append(.split(newDistribution: newDistribution))
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
        // 無料ユーザーは1日の回数制限あり（プレミアムは無制限）
        if !StoreManager.shared.isPremium {
            guard SettingsStore.shared.consumeHint() else {
                hintLimitReached = true
                return
            }
        }
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
            if case .split(let distribution) = action {
                let text = distribution.map(String.init).joined(separator: "-")
                self.battleEvent = BattleEvent(text: String(localized: "分割 \(text) が最善!"), color: .yellow)
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
            battleEvent = BattleEvent(text: String(localized: "あと10ターンで判定!"), color: .yellow)
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

    /// CPU戦勝利時のGame Center実績（未設定なら何も起きない）
    private func reportAchievements() {
        let gameCenter = GameCenterManager.shared
        let stats = GameStats.shared
        gameCenter.unlock(.firstWin)
        if stats.currentStreak >= 3 { gameCenter.unlock(.streak3) }
        if stats.currentStreak >= 10 { gameCenter.unlock(.streak10) }
        if isPerfectWin { gameCenter.unlock(.perfectWin) }
        if state.config.aiLevel == nil && state.config.aiDifficulty == .oni {
            gameCenter.unlock(.beatOni)
        }
        if state.config.aiLevel == GameStats.maxRankLevel {
            gameCenter.unlock(.rankMax)
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
        if !isMultiplayer {
            GameSessionStore.shared.clear()
        }
        lastReplay = Replay(
            initialState: replayInitialState,
            actions: actionLog,
            savedAt: .now,
            initialAttacksThisTurn: replayInitialAttacks
        )
        if winnerId != nil {
            HapticManager.victory()
        }
        GameStats.shared.recordDailyPlay()
        if isVsAI, let winnerId {
            let playerWon = winnerId == state.player1.id
            GameStats.shared.recordGame(playerWon: playerWon)
            if playerWon, state.config.aiLevel != nil {
                didRankUp = GameStats.shared.registerRankedWin()
                GameCenterManager.shared.submitRankLevel(GameStats.shared.rankLevel)
            }
            if playerWon {
                let clearsBefore = GameStats.shared.dailyChallengeClearCount
                let oniBefore = GameStats.shared.oniWins
                // 日/週をまたいだ中断再開・再戦では古いルールで勝っても
                // 新しい期間のクリアにしない（現在の生成ルールと一致する場合のみ記録）
                if state.config.isDailyChallenge, state.config == DailyChallenge.config() {
                    GameStats.shared.markDailyChallengeCleared()
                }
                if state.config.isWeeklyChallenge, state.config == WeeklyChallenge.config() {
                    GameStats.shared.markWeeklyChallengeCleared()
                }
                if state.config.aiLevel == nil && state.config.aiDifficulty == .oni {
                    GameStats.shared.recordOniWin()
                }
                // この勝利で解放条件をまたいだ報酬テーマがあれば演出する。
                // プレミアムテーマは常にロック扱い（before==after）なので検出されない
                let clearsAfter = GameStats.shared.dailyChallengeClearCount
                let oniAfter = GameStats.shared.oniWins
                unlockedRewardTheme = Theme.all.first { theme in
                    let lockedBefore = !theme.isUnlocked(
                        isPremiumPurchased: false, challengeClears: clearsBefore, oniWins: oniBefore
                    )
                    let unlockedNow = theme.isUnlocked(
                        isPremiumPurchased: false, challengeClears: clearsAfter, oniWins: oniAfter
                    )
                    return lockedBefore && unlockedNow
                }
                reportAchievements()
            }
        }
        // リザルトのサウンド（ランクアップ > 勝敗、引き分けは無音）
        if didRankUp {
            SoundManager.play(.rankup)
        } else if let winnerId {
            let localLost: Bool
            if isVsAI {
                localLost = winnerId == state.player2.id
            } else if isMultiplayer, let localId = localPlayerId {
                localLost = winnerId != localId
            } else {
                // 1台の2人対戦は必ず誰かが勝つので勝利音
                localLost = false
            }
            SoundManager.play(localLost ? .lose : .win)
        }
    }
}
