import XCTest
@testable import Chopsticks

/// GameViewModelの統合テスト。戦績・実績・保存セッションなどのシングルトンも触るため、各テストの前後で初期化する。
/// XCTest実行中はアプリ本来のデータとは別の保存領域（`AppDefaults`）を使うので、実データは消えない。
@MainActor
final class GameViewModelTests: XCTestCase {

    override func setUp() async throws {
        GameStats.shared.resetAll()
        AchievementStore.shared.reset()
        GameSessionStore.clear()
    }

    override func tearDown() async throws {
        GameStats.shared.resetAll()
        AchievementStore.shared.reset()
        GameSessionStore.clear()
    }

    // MARK: - Helpers

    private func localConfig(_ configure: (inout GameConfig) -> Void = { _ in }) -> GameConfig {
        var config = GameConfig()
        config.gameMode = .localTwoPlayer
        configure(&config)
        return config
    }

    /// 現在の手番のアクションをAIエンジンに選ばせ、ViewModelの公開APIで実行する
    @discardableResult
    private func playOneMove(_ vm: GameViewModel) -> Bool {
        guard !vm.isGameOver,
              let action = AIEngine.chooseAction(state: vm.state, difficulty: .hard, attacksUsedThisTurn: vm.attacksThisTurn)
        else { return false }
        switch action {
        case .tap(let attacker, let target):
            vm.selectAttackerHand(attacker)
            vm.tapOpponentHand(target)
        case .split(let distribution):
            vm.performSplit(newDistribution: distribution)
        }
        return true
    }

    /// 盤面が同じか。プレイヤー名は各端末から見た呼び名（「あなた」など）が違うので比べない。
    private func assertSameBoard(_ a: GameState, _ b: GameState, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(a.player1.id, b.player1.id, message, file: file, line: line)
        XCTAssertEqual(a.player2.id, b.player2.id, message, file: file, line: line)
        XCTAssertEqual(a.player1.hands, b.player1.hands, message, file: file, line: line)
        XCTAssertEqual(a.player2.hands, b.player2.hands, message, file: file, line: line)
        XCTAssertEqual(a.currentPlayerId, b.currentPlayerId, message, file: file, line: line)
        XCTAssertEqual(a.phase, b.phase, message, file: file, line: line)
        XCTAssertEqual(a.turnCount, b.turnCount, message, file: file, line: line)
        XCTAssertEqual(a.config, b.config, message, file: file, line: line)
    }

    /// 条件が満たされるまで待つ（固定時間の待機は、遅い環境で結果が不安定になる）
    private func waitUntil(timeout: Duration = .seconds(5), _ condition: () -> Bool) async {
        let end = ContinuousClock.now + timeout
        while !condition() && ContinuousClock.now < end {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    // MARK: - ローカル対戦

    func testLocalGameRunsToCompletionAndRecordsStats() async {
        let vm = GameViewModel(config: localConfig())
        var guardCount = 0
        while !vm.isGameOver && guardCount < 200 {
            playOneMove(vm)
            guardCount += 1
        }
        XCTAssertTrue(vm.isGameOver)
        XCTAssertLessThanOrEqual(vm.state.turnCount, GameViewModel.turnLimit)
        XCTAssertNotNil(vm.lastSummary)
        XCTAssertEqual(GameStats.shared.totalGames, 1)
        XCTAssertEqual(GameStats.shared.localGames, 1)
        XCTAssertNotNil(vm.rewards)
        XCTAssertGreaterThan(vm.rewards?.xpGained ?? 0, 0)
        XCTAssertTrue(AchievementStore.shared.isUnlocked(.localDuel))
        XCTAssertNil(GameSessionStore.load(), "終了したゲームは保存を残さない")
        let score = vm.sessionScore.player1 + vm.sessionScore.player2
        XCTAssertEqual(score, vm.isDraw ? 0 : 1)
        // 遊んだターン数は、決着した手を含めて数える（画面のターン表示と同じ）
        if let summary = vm.lastSummary, !summary.decidedBySuddenDeath {
            XCTAssertEqual(summary.turnCount, vm.state.turnCount + 1)
        }
    }

    func testLocalRematchAlternatesStartingPlayer() async {
        let vm = GameViewModel(config: localConfig())
        XCTAssertTrue(vm.isPlayer1Turn)
        vm.newGame()
        XCTAssertFalse(vm.isPlayer1Turn, "2人対戦の再戦は先手を交代")
        vm.newGame()
        XCTAssertTrue(vm.isPlayer1Turn)
    }

    func testHandsAreNotInteractiveForWrongTurnTaps() async {
        let vm = GameViewModel(config: localConfig())
        let opponentHand = vm.opponentPlayer.hands[0].id
        vm.handleHandTap(opponentHand)  // 攻撃手を選ぶ前の相手タップは無視
        XCTAssertNil(vm.selectedAttackerHandId)
        XCTAssertEqual(vm.state.turnCount, 0)
        vm.handleHandTap(vm.currentPlayer.hands[0].id)
        XCTAssertNotNil(vm.selectedAttackerHandId)
        vm.handleHandTap(vm.currentPlayer.hands[0].id)
        XCTAssertNil(vm.selectedAttackerHandId, "もう一度タップで選択解除")
    }

    func testSplitPanelOnlyWhenValidSplitExists() async {
        let vm = GameViewModel(config: localConfig { $0.isSplittingEnabled = true })
        XCTAssertFalse(vm.canSplitNow, "[1,1]からは有効な分割がない")
        vm.selectAttackerHand(vm.currentPlayer.hands[0].id)
        vm.tapOpponentHand(vm.opponentPlayer.hands[0].id)  // P2が[2,1]に
        // P2の手番: [2,1] → [3,0]は自分殺しで不可、[1,2]は並べ替えで不可
        XCTAssertFalse(vm.canSplitNow)
    }

    func testDoubleTapGivesTwoAttacksPerTurn() async {
        let vm = GameViewModel(config: localConfig { $0.isDoubleTapEnabled = true })
        let startingPlayer = vm.state.currentPlayerId
        vm.selectAttackerHand(vm.currentPlayer.hands[0].id)
        vm.tapOpponentHand(vm.opponentPlayer.hands[0].id)
        XCTAssertEqual(vm.state.currentPlayerId, startingPlayer, "1回目の攻撃のあとも同じ手番")
        XCTAssertEqual(vm.attacksThisTurn, 1)
        vm.selectAttackerHand(vm.currentPlayer.hands[1].id)
        vm.tapOpponentHand(vm.opponentPlayer.hands[1].id)
        XCTAssertNotEqual(vm.state.currentPlayerId, startingPlayer)
        XCTAssertEqual(vm.attacksThisTurn, 0)
    }

    /// ルールに基づく危険判定（リーチ表示）。4本の手は1本の攻撃で死に、相手の1本の手も4本の攻撃で死ぬ。
    func testThreatenedHandsFollowRules() async {
        XCTAssertTrue(GameViewModel(config: localConfig()).threatenedHandIds.isEmpty, "開幕に危険な手はない")

        var state = GameState(config: localConfig())
        state.player1.hands[0].fingerCount = 4   // P2の1本攻撃で 4+1=5 → 死
        let vm = GameViewModel(savedGame: SavedGame(state: state, attacksThisTurn: 0, savedAt: Date()))
        XCTAssertEqual(
            vm.threatenedHandIds,
            [state.player1.hands[0].id, state.player2.hands[0].id, state.player2.hands[1].id],
            "P1の4本と、P1の4本の攻撃で死ぬP2の1本×2が危険。P1の1本は危険でない"
        )
    }

    func testNothingIsSavedBeforeTheFirstMove() async {
        var config = GameConfig()
        config.gameMode = .vsAI
        config.aiDifficulty = .easy
        let vm = GameViewModel(config: config)
        vm.skipsPacingDelays = true
        vm.suspendGame()
        XCTAssertNil(GameSessionStore.load(), "1手も指していない対戦は「続きから」に出さない")
        vm.selectAttackerHand(vm.currentPlayer.hands[0].id)
        vm.tapOpponentHand(vm.opponentPlayer.hands[0].id)
        XCTAssertNotNil(GameSessionStore.load())
    }

    // MARK: - CPU戦

    func testAITurnBlocksInputAndThenMoves() async {
        var config = GameConfig()
        config.gameMode = .vsAI
        config.aiLevel = 1
        let vm = GameViewModel(config: config)
        vm.skipsPacingDelays = true
        XCTAssertTrue(vm.isHumanTurn)
        vm.selectAttackerHand(vm.currentPlayer.hands[0].id)
        vm.tapOpponentHand(vm.opponentPlayer.hands[0].id)
        XCTAssertTrue(vm.isAITurn)
        XCTAssertFalse(vm.isHumanTurn)
        // AIの手番中の入力は受け付けない
        vm.selectAttackerHand(vm.state.player1.hands[0].id)
        XCTAssertNil(vm.selectedAttackerHandId.flatMap { vm.state.player1.hand(for: $0) })
        await waitUntil { vm.state.turnCount == 2 }
        XCTAssertEqual(vm.state.turnCount, 2, "AIが1手指して人間の手番に戻る")
        XCTAssertTrue(vm.isHumanTurn)
    }

    func testRankedGameStatsAfterLossAndAbandon() async {
        var config = GameConfig()
        config.gameMode = .vsAI
        config.aiLevel = 1
        let vm = GameViewModel(config: config)
        vm.abandonGame()
        XCTAssertEqual(GameStats.shared.losses, 0, "1手も指していない対戦の破棄は負けにしない")

        let vm2 = GameViewModel(config: config)
        vm2.skipsPacingDelays = true
        vm2.selectAttackerHand(vm2.currentPlayer.hands[0].id)
        vm2.tapOpponentHand(vm2.opponentPlayer.hands[0].id)
        vm2.abandonGame()
        XCTAssertEqual(GameStats.shared.losses, 1, "指し始めたランク戦の破棄は負け扱い")
        XCTAssertNil(GameSessionStore.load())
    }

    func testSuspendAndResumeKeepsState() async {
        var config = GameConfig()
        config.gameMode = .vsAI
        config.aiDifficulty = .easy
        let vm = GameViewModel(config: config)
        vm.skipsPacingDelays = true
        vm.selectAttackerHand(vm.currentPlayer.hands[0].id)
        vm.tapOpponentHand(vm.opponentPlayer.hands[0].id)
        vm.suspendGame()
        guard let saved = GameSessionStore.load() else { return XCTFail("保存されているはず") }
        XCTAssertEqual(saved.state.turnCount, 1)
        let resumed = GameViewModel(savedGame: saved)
        XCTAssertEqual(resumed.state, saved.state)
        XCTAssertTrue(resumed.isAITurn)
    }

    // MARK: - マルチプレイ

    /// ホストとゲストを作り、画面表示（setupMultiplayer）まで進める。
    /// `hostFirst`がfalseなら、ゲストが先に準備できる（順序依存の確認用）。
    private func makeMatch(config: GameConfig? = nil, hostFirst: Bool = true)
        -> (host: GameViewModel, guest: GameViewModel, hostService: MockMultiplayerService, guestService: MockMultiplayerService)
    {
        var cfg = config ?? GameConfig()
        cfg.gameMode = .nearby
        let (hostService, guestService) = MockMultiplayerService.makePair()
        let host = GameViewModel(config: cfg)
        let guest = GameViewModel(config: cfg)
        host.skipsPacingDelays = true
        guest.skipsPacingDelays = true
        if hostFirst {
            host.setupMultiplayer(service: hostService)
            guest.setupMultiplayer(service: guestService)
        } else {
            guest.setupMultiplayer(service: guestService)
            host.setupMultiplayer(service: hostService)
        }
        return (host, guest, hostService, guestService)
    }

    func testGuestReceivesGameStartEvenIfHostStartedFirst() async {
        // ホストが先に画面を開いて gameStart を送っても、ゲストのハンドラ設定前のメッセージは失われない
        let m = makeMatch(hostFirst: true)
        XCTAssertFalse(m.guest.isWaitingForHost)
        XCTAssertEqual(m.guest.state.player1.id, m.host.state.player1.id)
        XCTAssertEqual(m.guest.state.player2.id, m.host.state.player2.id)
        XCTAssertEqual(m.guest.localPlayerId, m.host.state.player2.id)
        XCTAssertEqual(m.host.localPlayerId, m.host.state.player1.id)
        XCTAssertEqual(m.guest.bottomPlayer.id, m.guest.state.player2.id, "ゲストでも自分が画面下")
        XCTAssertEqual(m.guest.bottomPlayer.name, "あなた")
        XCTAssertEqual(m.guest.topPlayer.name, "ホスト")
        XCTAssertTrue(m.host.showRules)
        XCTAssertTrue(m.guest.showRules)
    }

    func testGuestWaitsUntilHostArrives() async {
        let m = makeMatch(hostFirst: false)
        XCTAssertFalse(m.guest.isWaitingForHost, "ホストが後から来ても同期される")
        XCTAssertEqual(m.guest.state.player1.id, m.host.state.player1.id)
    }

    func testActionsSyncBothWaysAndInputIsGatedByTurn() async {
        let m = makeMatch()
        // ホストの手番: ゲストは操作できない
        XCTAssertTrue(m.host.isHumanTurn)
        XCTAssertFalse(m.guest.isHumanTurn)
        m.guest.selectAttackerHand(m.guest.state.player2.hands[0].id)
        XCTAssertNil(m.guest.selectedAttackerHandId)

        m.host.selectAttackerHand(m.host.state.player1.hands[0].id)
        m.host.tapOpponentHand(m.host.state.player2.hands[0].id)
        await waitUntil { m.guest.state.turnCount == 1 }
        assertSameBoard(m.guest.state, m.host.state)
        XCTAssertTrue(m.guest.isHumanTurn)
        XCTAssertFalse(m.host.isHumanTurn)

        m.guest.selectAttackerHand(m.guest.state.player2.hands[1].id)
        m.guest.tapOpponentHand(m.guest.state.player1.hands[1].id)
        await waitUntil { m.host.state.turnCount == 2 }
        assertSameBoard(m.guest.state, m.host.state)
        XCTAssertEqual(m.host.state.turnCount, 2)
    }

    /// 2つの操作がまとめて届いても、順番どおりに適用される（ダブルタップで同じ手番に2回送る）
    func testRemoteActionsApplyInOrderEvenWhenBurstDelivered() async {
        var cfg = GameConfig()
        cfg.isDoubleTapEnabled = true
        let m = makeMatch(config: cfg)
        m.hostService.holdsOutgoing = true
        m.host.selectAttackerHand(m.host.state.player1.hands[0].id)
        m.host.tapOpponentHand(m.host.state.player2.hands[0].id)
        m.host.selectAttackerHand(m.host.state.player1.hands[1].id)
        m.host.tapOpponentHand(m.host.state.player2.hands[1].id)
        let sentActions = m.hostService.sent.filter { if case .action = $0 { return true } else { return false } }
        XCTAssertEqual(sentActions.count, 2, "前提: 2つの操作を溜めてある")
        XCTAssertEqual(m.guest.state.turnCount, 0, "まだ届いていない")

        m.hostService.holdsOutgoing = false
        m.hostService.flushOutgoing()
        await waitUntil { m.guest.state.turnCount == 1 }
        assertSameBoard(m.guest.state, m.host.state)
    }

    /// ホスト・ゲストの両方でAIエンジンを使い、ネットワーク越しに1ゲームを最後まで進める
    private func playMatchToCompletion(_ m: (host: GameViewModel, guest: GameViewModel, hostService: MockMultiplayerService, guestService: MockMultiplayerService)) async {
        var steps = 0
        while !m.host.isGameOver && steps < 300 {
            let actor = m.host.isHumanTurn ? m.host : m.guest
            let other = actor === m.host ? m.guest : m.host
            playOneMove(actor)
            // 相手側に反映されるまで待つ
            await waitUntil { other.state.turnCount == actor.state.turnCount && other.isGameOver == actor.isGameOver }
            steps += 1
        }
        await waitUntil { m.guest.isGameOver == m.host.isGameOver }
    }

    func testMatchRunsToCompletionAndBothSidesAgree() async {
        let m = makeMatch()
        await playMatchToCompletion(m)
        XCTAssertTrue(m.host.isGameOver)
        XCTAssertTrue(m.guest.isGameOver)
        assertSameBoard(m.host.state, m.guest.state)
        if let hostWon = m.host.didLocalPlayerWin, let guestWon = m.guest.didLocalPlayerWin {
            XCTAssertNotEqual(hostWon, guestWon, "片方だけが勝つ")
        } else {
            XCTAssertTrue(m.host.isDraw && m.guest.isDraw)
        }
        XCTAssertEqual(m.host.lastSummary?.mode, .nearby)
    }

    func testRematchRequestedByGuestAcceptedByHost() async {
        let m = makeMatch()
        await playMatchToCompletion(m)
        m.guest.requestRematch()
        XCTAssertTrue(m.guest.isWaitingForRematch)
        XCTAssertTrue(m.host.showRematchRequest)
        m.host.acceptRematch()
        await waitUntil { !m.guest.isGameOver && !m.host.isGameOver }
        XCTAssertFalse(m.host.isGameOver)
        XCTAssertFalse(m.guest.isGameOver)
        assertSameBoard(m.host.state, m.guest.state, "ホストが配った新しい盤面にゲストが同期する")
        XCTAssertFalse(m.guest.isWaitingForHost)
        XCTAssertFalse(m.guest.isWaitingForRematch)
        XCTAssertEqual(m.guest.localPlayerId, m.host.state.player2.id)
        XCTAssertEqual(m.host.state.currentPlayerId, m.host.state.player2.id, "再戦は先手交代（ゲストが先手）")
        XCTAssertTrue(m.guest.isHumanTurn)
    }

    func testSimultaneousRematchRequestsStartExactlyOneNewGame() async {
        let m = makeMatch()
        await playMatchToCompletion(m)
        m.hostService.holdsOutgoing = true
        m.guestService.holdsOutgoing = true
        m.host.requestRematch()
        m.guest.requestRematch()
        // 両方の要求が「すれ違った」状態で届ける。返信は即時に届くよう、先に保留を解除する。
        m.hostService.holdsOutgoing = false
        m.guestService.holdsOutgoing = false
        m.hostService.flushOutgoing()
        m.guestService.flushOutgoing()
        await waitUntil { !m.guest.isGameOver && !m.host.isGameOver }
        XCTAssertFalse(m.host.isGameOver)
        XCTAssertFalse(m.guest.isGameOver)
        assertSameBoard(m.host.state, m.guest.state)
        let gameStarts = m.hostService.sent.filter { if case .gameStart = $0 { return true } else { return false } }
        XCTAssertEqual(gameStarts.count, 2, "最初の開始 + 再戦の開始 の2回だけ")
        XCTAssertFalse(m.host.isWaitingForRematch)
        XCTAssertFalse(m.guest.isWaitingForRematch)
        XCTAssertFalse(m.host.showRematchRequest)
        XCTAssertFalse(m.guest.showRematchRequest)
    }

    func testRematchDeclinedEndsSession() async {
        let m = makeMatch()
        await playMatchToCompletion(m)
        m.guest.requestRematch()
        m.host.declineRematch()
        await waitUntil { m.guest.notice != nil }
        XCTAssertEqual(m.guest.notice, .rematchDeclined)
        XCTAssertTrue(m.guest.isConnectionLost)
        XCTAssertFalse(m.guest.isWaitingForRematch)
    }

    /// 相手の方が先に決着画面に着いて要求を送ってきても、こちらの決着後に通知される
    func testRematchRequestArrivingBeforeOwnGameOverIsShownAfterwards() async {
        let m = makeMatch()
        m.guestService.deliverToSelf(.rematchRequest)
        XCTAssertFalse(m.guest.showRematchRequest, "まだ決着していないので出さない")
        await playMatchToCompletion(m)
        XCTAssertTrue(m.guest.showRematchRequest, "決着後に通知される")
    }

    func testDuplicateGameStartDoesNotWipeGameInProgress() async {
        let m = makeMatch()
        m.host.selectAttackerHand(m.host.state.player1.hands[0].id)
        m.host.tapOpponentHand(m.host.state.player2.hands[0].id)
        await waitUntil { m.guest.state.turnCount == 1 }
        let before = m.guest.state
        m.guestService.deliverToSelf(.gameStart(GameState(config: before.config)))
        XCTAssertEqual(m.guest.state, before)
    }

    func testConnectionDropShowsNoticeAndBlocksInput() async {
        let m = makeMatch()
        m.guestService.simulateConnectionDrop()
        XCTAssertEqual(m.guest.notice, .connectionLost)
        XCTAssertTrue(m.guest.isConnectionLost)
        XCTAssertFalse(m.guest.isWaitingForHost)
        // 二重に通知しない
        m.guest.notice = nil
        m.guestService.simulateConnectionDrop()
        XCTAssertNil(m.guest.notice)
    }

    func testOpponentLeavingIsReportedDistinctlyFromDrop() async {
        let m = makeMatch()
        m.guest.leaveMultiplayer()
        XCTAssertEqual(m.host.notice, .opponentLeft)
    }

    func testBackgroundingEndsMultiplayerWithExplanation() async {
        let m = makeMatch()
        m.host.handleAppBackgrounded()
        XCTAssertEqual(m.host.notice, .movedToBackground)
        XCTAssertEqual(m.guest.notice, .opponentLeft)
    }

    func testSetupIsIdempotent() async {
        let m = makeMatch()
        let state = m.host.state
        m.host.setupMultiplayer(service: m.hostService)
        XCTAssertEqual(m.host.state, state, "onAppearが複数回呼ばれても盤面を作り直さない")
    }

    func testSetupAfterLeavingIsIgnored() async {
        let m = makeMatch()
        m.host.leaveMultiplayer()
        let sentBefore = m.hostService.sent.count
        m.host.setupMultiplayer(service: m.hostService)
        XCTAssertEqual(m.hostService.sent.count, sentBefore, "切断後のonAppearで、開始メッセージを再送しない")
    }

    /// 結果画面から退出しても、勝敗の判定と盤面の上下が入れ替わらない
    func testLeavingDoesNotFlipTheResultScreen() async {
        let m = makeMatch()
        await playMatchToCompletion(m)
        let winBefore = m.guest.didLocalPlayerWin
        let bottomBefore = m.guest.bottomPlayer.id
        m.guest.leaveMultiplayer()
        XCTAssertEqual(m.guest.didLocalPlayerWin, winBefore)
        XCTAssertEqual(m.guest.bottomPlayer.id, bottomBefore)
    }

    func testDisconnectBeforeGameViewAppearsIsDetected() async {
        let (hostService, _) = MockMultiplayerService.makePair()
        hostService.isConnected = false
        var cfg = GameConfig()
        cfg.gameMode = .nearby
        let host = GameViewModel(config: cfg)
        host.setupMultiplayer(service: hostService)
        XCTAssertEqual(host.notice, .connectionLost, "ルール確認中に切れていた接続を、ゲーム画面で検知する")
    }

    // MARK: - MessageInbox

    func testInboxBuffersUntilHandlerSet() async {
        let inbox = MessageInbox()
        inbox.deliver(.rematchRequest)
        inbox.deliver(.rematchAccepted)
        var received: [String] = []
        inbox.onMessageReceived = { message in
            switch message {
            case .rematchRequest: received.append("request")
            case .rematchAccepted: received.append("accepted")
            default: received.append("other")
            }
        }
        XCTAssertEqual(received, ["request", "accepted"])
        inbox.deliver(.disconnect)
        XCTAssertEqual(received.last, "other")
    }

    func testMultiplayerMessagesRoundTripThroughCodable() async throws {
        var cfg = GameConfig()
        cfg.gameMode = .online
        let messages: [MultiplayerMessage] = [
            .gameStart(GameState(config: cfg)), .rematchRequest, .rematchAccepted,
            .rematchDeclined, .playerLeft, .disconnect,
        ]
        for message in messages {
            let data = try XCTUnwrap(message.encoded())
            XCTAssertNotNil(MultiplayerMessage.decoded(from: data))
        }
    }
}
