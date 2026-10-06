import Foundation
import MultipeerConnectivity
import Observation

@Observable
@MainActor
final class MultipeerService: NSObject, MultiplayerService {
    static let serviceType = "chopsticks"

    // MARK: - MultiplayerService
    private let inbox = MessageInbox()
    var onMessageReceived: ((MultiplayerMessage) -> Void)? {
        get { inbox.onMessageReceived }
        set { inbox.onMessageReceived = newValue }
    }
    @ObservationIgnored var onConnectionChanged: ((Bool) -> Void)?
    @ObservationIgnored private(set) var isHost: Bool
    var opponentName: String { connectedPeerName ?? "対戦相手" }

    // MARK: - Observable state（画面が監視するものだけ）
    private(set) var discoveredPeers: [MCPeerID] = []
    private(set) var isConnected = false
    private(set) var receivedInvitation: (from: MCPeerID, handler: (Bool, MCSession?) -> Void)?
    /// 直近のエラー（ローカルネットワークの許可なし・接続拒否など）
    private(set) var lastError: String?
    /// `lastError`が権限（ローカルネットワーク）の問題か。trueのときだけ「設定を開く」を案内する。
    private(set) var lastErrorIsPermission = false
    /// 接続試行中（招待送信〜接続完了）
    private(set) var isConnecting = false

    // MARK: - Private（監視不要）
    private let myPeerId: MCPeerID
    @ObservationIgnored private var session: MCSession!
    @ObservationIgnored private var advertiser: MCNearbyServiceAdvertiser?
    @ObservationIgnored private var browser: MCNearbyServiceBrowser?
    @ObservationIgnored private var connectedPeerName: String?
    @ObservationIgnored private var didDisconnectIntentionally = false

    init(displayName: String, isHost: Bool) {
        // MCPeerIDの表示名は63バイト（UTF-8）まで。超えると例外で落ちるので文字単位で削る。
        var name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { name = "プレイヤー" }
        while name.utf8.count > 63 { name.removeLast() }
        self.myPeerId = MCPeerID(displayName: name)
        self.isHost = isHost
        super.init()
        self.session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .required)
        self.session.delegate = self
    }

    // MARK: - Host: Advertise
    func startAdvertising() {
        clearError()
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: nil, serviceType: Self.serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

    // MARK: - Guest: Browse
    func startBrowsing() {
        clearError()
        browser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: Self.serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    func invitePeer(_ peerID: MCPeerID) {
        isConnecting = true
        clearError()
        browser?.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }

    func acceptInvitation() {
        isConnecting = true
        receivedInvitation?.handler(true, session)
        receivedInvitation = nil
    }

    func declineInvitation() {
        receivedInvitation?.handler(false, nil)
        receivedInvitation = nil
    }

    /// 接続が成立しないまま待たされたときに、試行を諦めて元の待機状態へ戻す
    func abortConnecting() {
        isConnecting = false
        lastError = "接続できませんでした。もう一度お試しください。"
        lastErrorIsPermission = false
    }

    private func clearError() {
        lastError = nil
        lastErrorIsPermission = false
    }

    // MARK: - MultiplayerService
    func send(_ message: MultiplayerMessage) {
        guard let data = message.encoded(),
              !session.connectedPeers.isEmpty else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    func disconnect() {
        send(.disconnect)
        stop()
    }

    /// 探索・接続をすべて止める（自分から切る場合はコールバックを出さない）
    func stop() {
        didDisconnectIntentionally = true
        onConnectionChanged = nil
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser = nil
        // 保留中の招待は断って、相手が30秒待たされないようにする
        receivedInvitation?.handler(false, nil)
        receivedInvitation = nil
        let closing: MCSession = session
        if closing.connectedPeers.isEmpty {
            closing.disconnect()
        } else {
            // 直前に送った「退出」などが相手に届くまで少し待ってから切る
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                closing.disconnect()
            }
        }
        isConnected = false
        isConnecting = false
        discoveredPeers = []
    }
}

// MARK: - MCSessionDelegate
extension MultipeerService: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let name = peerID.displayName
        deliverOnMain { [weak self] in
            guard let self else { return }
            switch state {
            case .connected:
                self.connectedPeerName = name
                self.isConnected = true
                self.isConnecting = false
                self.advertiser?.stopAdvertisingPeer()
                self.browser?.stopBrowsingForPeers()
                self.onConnectionChanged?(true)
            case .notConnected:
                let wasConnected = self.isConnected
                let wasConnecting = self.isConnecting
                self.connectedPeerName = nil
                self.isConnected = false
                self.isConnecting = false
                if self.didDisconnectIntentionally { return }
                if wasConnecting && !wasConnected {
                    self.lastError = "接続できませんでした。相手が断ったか、時間切れです。"
                    self.lastErrorIsPermission = false
                }
                self.onConnectionChanged?(false)
            case .connecting:
                self.isConnecting = true
            @unknown default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = MultiplayerMessage.decoded(from: data) else { return }
        deliverOnMain { [weak self] in
            self?.inbox.deliver(message)
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MultipeerService: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        deliverOnMain { [weak self] in
            guard let self else {
                invitationHandler(false, nil)
                return
            }
            // 新しい招待で置き換わる古い招待は断る（ハンドラを呼ばないと相手が待ち続ける）
            self.receivedInvitation?.handler(false, nil)
            self.receivedInvitation = (from: peerID, handler: invitationHandler)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        deliverOnMain { [weak self] in
            self?.lastError = "近くのプレイヤーに公開できませんでした。設定でローカルネットワークを許可してください。"
            self?.lastErrorIsPermission = true
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension MultipeerService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        deliverOnMain { [weak self] in
            guard let self else { return }
            if !self.discoveredPeers.contains(peerID) {
                self.discoveredPeers.append(peerID)
            }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        deliverOnMain { [weak self] in
            self?.discoveredPeers.removeAll { $0 == peerID }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        deliverOnMain { [weak self] in
            self?.lastError = "近くのプレイヤーを探せませんでした。設定でローカルネットワークを許可してください。"
            self?.lastErrorIsPermission = true
        }
    }
}
