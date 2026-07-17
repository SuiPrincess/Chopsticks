import XCTest
@testable import Chopsticks

/// 送受信を記録するテスト用のマルチプレイサービス
@MainActor
final class MockMultiplayerService: MultiplayerService {
    var onMessageReceived: ((MultiplayerMessage) -> Void)?
    var onConnectionChanged: ((Bool) -> Void)?
    var isHost: Bool
    var opponentName: String = "相手"
    var localPlayerName: String = "自分"
    private(set) var isConnected: Bool = true
    private(set) var sentMessages: [MultiplayerMessage] = []

    init(isHost: Bool) {
        self.isHost = isHost
    }

    func send(_ message: MultiplayerMessage) {
        sentMessages.append(message)
    }

    func disconnect() {
        isConnected = false
    }

    /// 相手からのメッセージ受信をシミュレート
    func simulateReceive(_ message: MultiplayerMessage) {
        onMessageReceived?(message)
    }
}

@MainActor
final class MultiplayerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        GameSessionStore.shared.clear()
    }

    override func tearDown() {
        GameSessionStore.shared.clear()
        super.tearDown()
    }

    private func makeHostGame() -> (GameViewModel, MockMultiplayerService) {
        var config = GameConfig()
        config.gameMode = .nearby
        let viewModel = GameViewModel(config: config)
        let service = MockMultiplayerService(isHost: true)
        viewModel.setupMultiplayer(service: service)
        viewModel.startMultiplayerGame(
            asHost: true,
            opponentName: service.opponentName,
            localName: service.localPlayerName
        )
        return (viewModel, service)
    }

    private func isGameStart(_ message: MultiplayerMessage) -> Bool {
        if case .gameStart = message { return true }
        return false
    }

    // MARK: - 開始・名前

    func testHostSendsGameStartWithPlayerNames() {
        let (viewModel, service) = makeHostGame()
        XCTAssertEqual(service.sentMessages.filter(isGameStart).count, 1)
        XCTAssertEqual(viewModel.state.player1.name, "自分")
        XCTAssertEqual(viewModel.state.player2.name, "相手")
        XCTAssertEqual(viewModel.localPlayerId, viewModel.state.player1.id)
        XCTAssertFalse(viewModel.isGuestPerspective)
    }

    func testGuestAdoptsHostStateAndPerspective() {
        var config = GameConfig()
        config.gameMode = .nearby
        let viewModel = GameViewModel(config: config)
        let service = MockMultiplayerService(isHost: false)
        viewModel.setupMultiplayer(service: service)

        var hostState = GameState(config: config)
        hostState.player1 = Player(name: "ホスト", handCount: 2)
        hostState.player2 = Player(name: "ゲスト", handCount: 2)
        hostState.currentPlayerId = hostState.player1.id
        service.simulateReceive(.gameStart(hostState))

        XCTAssertEqual(viewModel.state, hostState)
        XCTAssertEqual(viewModel.localPlayerId, hostState.player2.id)
        XCTAssertTrue(viewModel.isGuestPerspective, "ゲストは自分＝player2を手前に表示")
        XCTAssertTrue(viewModel.isRemoteControlled, "ホストの手番では操作不可")
    }

    // MARK: - リマッチ

    func testAcceptRematchAsHostBroadcastsNewGameState() {
        let (viewModel, service) = makeHostGame()
        let oldHandIds = Set(viewModel.state.player1.hands.map(\.id))

        service.simulateReceive(.rematchRequest)
        XCTAssertTrue(viewModel.showRematchRequest)
        viewModel.acceptRematch()

        // 承認側ホストも必ず新しい盤面を配布する（desync防止）
        XCTAssertEqual(service.sentMessages.filter(isGameStart).count, 2)
        let newHandIds = Set(viewModel.state.player1.hands.map(\.id))
        XCTAssertTrue(oldHandIds.isDisjoint(with: newHandIds), "再戦は新しい盤面")
    }

    func testRematchAcceptedIgnoredWhenNotWaiting() {
        let (viewModel, service) = makeHostGame()
        let stateBefore = viewModel.state
        // 自分が要求していないのに承認だけが届いた（同時リマッチの交差など）
        service.simulateReceive(.rematchAccepted)
        XCTAssertEqual(viewModel.state, stateBefore, "待機していなければ無視する")
    }

    func testRematchDeclinedShowsLeaveMessage() {
        let (viewModel, service) = makeHostGame()
        viewModel.requestRematch()
        XCTAssertTrue(viewModel.isWaitingForRematch)
        service.simulateReceive(.rematchDeclined)
        XCTAssertFalse(viewModel.isWaitingForRematch)
        XCTAssertTrue(viewModel.showDisconnectAlert)
        XCTAssertEqual(viewModel.disconnectMessage, "相手が退出しました")
    }

    // MARK: - セーブとの分離

    func testMultiplayerDoesNotTouchSinglePlayerSave() {
        // 先にシングルプレイの中断セーブを作る
        var soloState = GameState(config: GameConfig())
        soloState.turnCount = 5
        GameSessionStore.shared.save(state: soloState, attacksThisTurn: 0)
        XCTAssertNotNil(GameSessionStore.shared.savedGame)

        // マルチプレイを開始して再戦（newGame相当）しても消えない
        let (viewModel, service) = makeHostGame()
        service.simulateReceive(.rematchRequest)
        viewModel.acceptRematch()
        XCTAssertNotNil(GameSessionStore.shared.savedGame,
                        "マルチプレイがシングルプレイのセーブを消してはいけない")
    }

    // MARK: - リモート操作ガード

    /// ホスト（player1）が1手指して相手（player2）の手番にする。
    /// 相手のhands[0]は 1+1=2 になる。
    private func advanceToOpponentTurn(_ viewModel: GameViewModel) {
        let attacker = viewModel.state.player1.hands[0]
        let target = viewModel.state.player2.hands[0]
        viewModel.handleHandTap(attacker.id)
        viewModel.handleHandTap(target.id)
        XCTAssertTrue(viewModel.isRemoteControlled, "相手の手番になっているはず")
    }

    private func makeSplittingHostGame() -> (GameViewModel, MockMultiplayerService) {
        var config = GameConfig()
        config.gameMode = .nearby
        config.isSplittingEnabled = true
        let viewModel = GameViewModel(config: config)
        let service = MockMultiplayerService(isHost: true)
        viewModel.setupMultiplayer(service: service)
        viewModel.startMultiplayerGame(
            asHost: true,
            opponentName: "相手",
            localName: "自分"
        )
        return (viewModel, service)
    }

    func testLocalSplitBlockedDuringOpponentTurn() {
        let (viewModel, _) = makeSplittingHostGame()
        advanceToOpponentTurn(viewModel) // 相手のhandsは(2,1)・合計3

        let before = viewModel.state
        viewModel.performSplit(newDistribution: [3, 0])
        XCTAssertEqual(viewModel.state, before,
                       "相手の手番にこちらから相手のSplitを実行できてはいけない")
    }

    func testRemoteActionStillAppliesDuringOpponentTurn() {
        let (viewModel, service) = makeSplittingHostGame()
        advanceToOpponentTurn(viewModel) // 相手のhandsは(2,1)・合計3

        service.simulateReceive(.action(.split(newDistribution: [3, 0])))
        XCTAssertEqual(viewModel.state.player2.hands.map(\.fingerCount), [3, 0],
                       "リモートから受信した正規のアクションは適用される")
        XCTAssertTrue(viewModel.isLocalTurn, "分割で手番がこちらへ戻る")
    }
}
