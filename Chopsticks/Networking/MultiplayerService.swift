import Foundation

@MainActor
protocol MultiplayerService: AnyObject {
    /// 受信ハンドラ。未設定の間に届いたメッセージはサービス側で保持し、設定時にまとめて配送する
    /// （ゲーム画面が表示される前にホストの`gameStart`が届いても失われない）。
    var onMessageReceived: ((MultiplayerMessage) -> Void)? { get set }
    var onConnectionChanged: ((Bool) -> Void)? { get set }
    var isHost: Bool { get }
    var opponentName: String { get }
    /// 相手と接続中か（ホスト決定済み）
    var isConnected: Bool { get }
    func send(_ message: MultiplayerMessage)
    func disconnect()
}

/// 受信メッセージのバッファリングを両サービスで共通化する
@MainActor
final class MessageInbox {
    private var pending: [MultiplayerMessage] = []
    private var handler: ((MultiplayerMessage) -> Void)?

    var onMessageReceived: ((MultiplayerMessage) -> Void)? {
        get { handler }
        set {
            handler = newValue
            flush()
        }
    }

    func deliver(_ message: MultiplayerMessage) {
        if let handler {
            handler(message)
        } else {
            pending.append(message)
        }
    }

    private func flush() {
        guard let handler, !pending.isEmpty else { return }
        let queued = pending
        pending = []
        for message in queued { handler(message) }
    }
}
