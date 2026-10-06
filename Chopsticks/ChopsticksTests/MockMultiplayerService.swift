import Foundation
@testable import Chopsticks

/// メモリ上でつなぐテスト用の通信サービス。実機のMultipeer/GameKitと同じ契約
/// （ハンドラ未設定の間のメッセージは保持される）を`MessageInbox`で再現する。
@MainActor
final class MockMultiplayerService: MultiplayerService {
    private let inbox = MessageInbox()
    var onMessageReceived: ((MultiplayerMessage) -> Void)? {
        get { inbox.onMessageReceived }
        set { inbox.onMessageReceived = newValue }
    }
    var onConnectionChanged: ((Bool) -> Void)?
    let isHost: Bool
    var opponentName: String
    var isConnected = true
    weak var peer: MockMultiplayerService?
    private(set) var sent: [MultiplayerMessage] = []
    /// trueの間は送信を溜めておき、`flushOutgoing()`でまとめて届ける（同時操作の再現用）
    var holdsOutgoing = false
    private var held: [MultiplayerMessage] = []

    init(isHost: Bool, opponentName: String) {
        self.isHost = isHost
        self.opponentName = opponentName
    }

    static func makePair() -> (host: MockMultiplayerService, guest: MockMultiplayerService) {
        let host = MockMultiplayerService(isHost: true, opponentName: "ゲスト")
        let guest = MockMultiplayerService(isHost: false, opponentName: "ホスト")
        host.peer = guest
        guest.peer = host
        return (host, guest)
    }

    func send(_ message: MultiplayerMessage) {
        sent.append(message)
        if holdsOutgoing {
            held.append(message)
        } else {
            peer?.inbox.deliver(message)
        }
    }

    func flushOutgoing() {
        let messages = held
        held = []
        for message in messages { peer?.inbox.deliver(message) }
    }

    func disconnect() {
        isConnected = false
        onConnectionChanged = nil
    }

    func simulateConnectionDrop() {
        isConnected = false
        onConnectionChanged?(false)
    }

    func deliverToSelf(_ message: MultiplayerMessage) {
        inbox.deliver(message)
    }
}
