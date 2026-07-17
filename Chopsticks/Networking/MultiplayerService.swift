import Foundation

@MainActor
protocol MultiplayerService: AnyObject {
    var onMessageReceived: ((MultiplayerMessage) -> Void)? { get set }
    var onConnectionChanged: ((Bool) -> Void)? { get set }
    var isHost: Bool { get }
    var opponentName: String { get }
    /// 自分の表示名（相手の画面に表示される）
    var localPlayerName: String { get }
    /// 現在接続中か。onConnectionChanged設定前に切断された場合の検知に使う。
    var isConnected: Bool { get }
    func send(_ message: MultiplayerMessage)
    func disconnect()
}
