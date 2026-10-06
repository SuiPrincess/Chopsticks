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
    var onConnectionChanged: ((Bool) -> Void)?
    private(set) var isHost: Bool
    var opponentName: String { connectedPeerName ?? "対戦相手" }

    // MARK: - Observable state
    private(set) var discoveredPeers: [MCPeerID] = []
    private(set) var isConnected = false
    private(set) var receivedInvitation: (from: MCPeerID, handler: (Bool, MCSession?) -> Void)?
    /// 直近のエラー（ローカルネットワークの許可なし・接続拒否など）
    private(set) var lastError: String?
    /// 接続試行中（招待送信〜接続完了）
    private(set) var isConnecting = false

    // MARK: - Private
    private let myPeerId: MCPeerID
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var connectedPeerName: String?
    private var didDisconnectIntentionally = false

    init(displayName: String, isHost: Bool) {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "プレイヤー" : String(trimmed.prefix(63))
        self.myPeerId = MCPeerID(displayName: name)
        self.isHost = isHost
        super.init()
        self.session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .required)
        self.session.delegate = self
    }

    // MARK: - Host: Advertise
    func startAdvertising() {
        lastError = nil
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: nil, serviceType: Self.serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

    // MARK: - Guest: Browse
    func startBrowsing() {
        lastError = nil
        browser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: Self.serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    func invitePeer(_ peerID: MCPeerID) {
        isConnecting = true
        lastError = nil
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
        session.disconnect()
        isConnected = false
        isConnecting = false
        discoveredPeers = []
        receivedInvitation = nil
    }
}

// MARK: - MCSessionDelegate
extension MultipeerService: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                self.connectedPeerName = peerID.displayName
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
        Task { @MainActor in
            self.inbox.deliver(message)
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MultipeerService: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            self.receivedInvitation = (from: peerID, handler: invitationHandler)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor in
            self.lastError = "近くのプレイヤーに公開できませんでした。設定でローカルネットワークを許可してください。"
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension MultipeerService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            if !self.discoveredPeers.contains(peerID) {
                self.discoveredPeers.append(peerID)
            }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.discoveredPeers.removeAll { $0 == peerID }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in
            self.lastError = "近くのプレイヤーを探せませんでした。設定でローカルネットワークを許可してください。"
        }
    }
}
