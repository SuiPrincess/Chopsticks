import GameKit

@MainActor
final class GameKitService: NSObject, MultiplayerService {
    // MARK: - MultiplayerService
    private let inbox = MessageInbox()
    var onMessageReceived: ((MultiplayerMessage) -> Void)? {
        get { inbox.onMessageReceived }
        set { inbox.onMessageReceived = newValue }
    }
    var onConnectionChanged: ((Bool) -> Void)?
    private(set) var isHost: Bool = false
    private(set) var isConnected: Bool = false
    var opponentName: String { remoteName ?? "対戦相手" }

    // MARK: - Private
    private var match: GKMatch?
    private var remoteName: String?

    /// マッチ成立直後はまだ相手が接続途中（`expectedPlayerCount > 0`）のことがある。
    /// 全員そろってからホストを決め、`onConnectionChanged(true)`を通知する。
    func configure(with match: GKMatch) {
        self.match = match
        match.delegate = self
        if match.expectedPlayerCount == 0 {
            finishSetup()
        }
    }

    private func finishSetup() {
        guard let match, !isConnected else { return }
        // ホスト判定: gamePlayerID の辞書順で先頭がホスト（両端末で同じ結果になる）
        let localId = GKLocalPlayer.local.gamePlayerID
        let allIds = ([localId] + match.players.map(\.gamePlayerID)).sorted()
        isHost = allIds.first == localId
        remoteName = match.players.first?.displayName
        isConnected = true
        onConnectionChanged?(true)
    }

    // MARK: - MultiplayerService
    func send(_ message: MultiplayerMessage) {
        guard let match, let data = message.encoded() else { return }
        do {
            try match.sendData(toAllPlayers: data, with: .reliable)
        } catch {
            // 送信失敗 — 接続切れの可能性
            handleLostConnection()
        }
    }

    func disconnect() {
        send(.disconnect)
        onConnectionChanged = nil
        isConnected = false
        let closing = match
        match = nil
        // 直前に送った「退出」などが相手に届くまで少し待ってから切る
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            closing?.delegate = nil
            closing?.disconnect()
        }
    }

    private func handleLostConnection() {
        guard match != nil else { return }
        isConnected = false
        onConnectionChanged?(false)
    }
}

// MARK: - GKMatchDelegate
extension GameKitService: GKMatchDelegate {
    nonisolated func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        guard let message = MultiplayerMessage.decoded(from: data) else { return }
        deliverOnMain { [weak self] in
            self?.inbox.deliver(message)
        }
    }

    nonisolated func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        let isComplete = match.expectedPlayerCount == 0
        deliverOnMain { [weak self] in
            switch state {
            case .connected:
                if isComplete {
                    self?.finishSetup()
                }
            case .disconnected:
                self?.handleLostConnection()
            default:
                break
            }
        }
    }

    nonisolated func match(_ match: GKMatch, didFailWithError error: Error?) {
        deliverOnMain { [weak self] in
            self?.handleLostConnection()
        }
    }
}
