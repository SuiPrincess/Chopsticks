import GameKit

@MainActor
final class GameKitService: NSObject, MultiplayerService {
    // MARK: - MultiplayerService
    var onMessageReceived: ((MultiplayerMessage) -> Void)?
    var onConnectionChanged: ((Bool) -> Void)?
    private(set) var isHost: Bool = false
    var opponentName: String { remoteName ?? "対戦相手" }

    // MARK: - Private
    private var match: GKMatch?
    private var remoteName: String?

    func configure(with match: GKMatch) {
        self.match = match
        match.delegate = self

        // ホスト判定: gamePlayerID の辞書順で先頭がホスト
        let localId = GKLocalPlayer.local.gamePlayerID
        let allIds = ([localId] + match.players.map(\.gamePlayerID)).sorted()
        isHost = allIds.first == localId

        remoteName = match.players.first?.displayName
        onConnectionChanged?(true)
    }

    // MARK: - MultiplayerService
    func send(_ message: MultiplayerMessage) {
        guard let match, let data = message.encoded() else { return }
        do {
            try match.sendData(toAllPlayers: data, with: .reliable)
        } catch {
            // 送信失敗 — 接続切れの可能性
            onConnectionChanged?(false)
        }
    }

    func disconnect() {
        send(.disconnect)
        match?.delegate = nil
        match?.disconnect()
        match = nil
    }
}

// MARK: - GKMatchDelegate
extension GameKitService: GKMatchDelegate {
    nonisolated func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        guard let message = MultiplayerMessage.decoded(from: data) else { return }
        Task { @MainActor in
            self.onMessageReceived?(message)
        }
    }

    nonisolated func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        Task { @MainActor in
            switch state {
            case .disconnected:
                self.onConnectionChanged?(false)
            default:
                break
            }
        }
    }

    nonisolated func match(_ match: GKMatch, didFailWithError error: Error?) {
        Task { @MainActor in
            self.onConnectionChanged?(false)
        }
    }
}
