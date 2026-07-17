import GameKit

@MainActor
final class GameKitService: NSObject, MultiplayerService {
    // MARK: - MultiplayerService
    /// ハンドラ未設定の間に届いたメッセージは失われないようバッファし、設定時に流す。
    /// （接続直後、相手が先に「ゲーム開始」を押すとgameStartがGameView表示前に届くことがある）
    var onMessageReceived: ((MultiplayerMessage) -> Void)? {
        didSet { flushPendingMessages() }
    }
    var onConnectionChanged: ((Bool) -> Void)?
    private(set) var isHost: Bool = false
    private(set) var isConnected: Bool = false
    var opponentName: String { remoteName ?? "対戦相手" }

    // MARK: - Private
    private var match: GKMatch?
    private var remoteName: String?
    private var pendingMessages: [MultiplayerMessage] = []

    fileprivate func deliverOrBuffer(_ message: MultiplayerMessage) {
        if let handler = onMessageReceived {
            handler(message)
        } else {
            pendingMessages.append(message)
        }
    }

    private func flushPendingMessages() {
        guard onMessageReceived != nil, !pendingMessages.isEmpty else { return }
        let queued = pendingMessages
        pendingMessages = []
        for message in queued {
            onMessageReceived?(message)
        }
    }

    func configure(with match: GKMatch) {
        self.match = match
        match.delegate = self

        // ホスト判定: gamePlayerID の辞書順で先頭がホスト
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
            isConnected = false
            onConnectionChanged?(false)
        }
    }

    func disconnect() {
        send(.disconnect)
        match?.delegate = nil
        match?.disconnect()
        match = nil
        isConnected = false
    }
}

// MARK: - GKMatchDelegate
extension GameKitService: GKMatchDelegate {
    nonisolated func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        guard let message = MultiplayerMessage.decoded(from: data) else { return }
        Task { @MainActor in
            self.deliverOrBuffer(message)
        }
    }

    nonisolated func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        Task { @MainActor in
            switch state {
            case .disconnected:
                self.isConnected = false
                self.onConnectionChanged?(false)
            default:
                break
            }
        }
    }

    nonisolated func match(_ match: GKMatch, didFailWithError error: Error?) {
        Task { @MainActor in
            self.isConnected = false
            self.onConnectionChanged?(false)
        }
    }
}
