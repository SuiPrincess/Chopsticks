import Foundation
import MultipeerConnectivity

@MainActor
final class MultipeerService: NSObject, MultiplayerService, ObservableObject {
    static let serviceType = "chopsticks"

    // MARK: - MultiplayerService
    var onMessageReceived: ((MultiplayerMessage) -> Void)?
    var onConnectionChanged: ((Bool) -> Void)?
    private(set) var isHost: Bool
    var opponentName: String { connectedPeerName ?? "対戦相手" }

    // MARK: - Published state
    @Published var discoveredPeers: [MCPeerID] = []
    @Published var isConnected = false
    @Published var receivedInvitation: (from: MCPeerID, handler: (Bool, MCSession?) -> Void)?

    // MARK: - Private
    private let myPeerId: MCPeerID
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var connectedPeerName: String?

    init(displayName: String, isHost: Bool) {
        self.myPeerId = MCPeerID(displayName: displayName)
        self.isHost = isHost
        super.init()
        self.session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .required)
        self.session.delegate = self
    }

    // MARK: - Host: Advertise
    func startAdvertising() {
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: nil, serviceType: Self.serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

    // MARK: - Guest: Browse
    func startBrowsing() {
        browser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: Self.serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    func invitePeer(_ peerID: MCPeerID) {
        browser?.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }

    func acceptInvitation() {
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
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session.disconnect()
        isConnected = false
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session.disconnect()
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
                self.advertiser?.stopAdvertisingPeer()
                self.browser?.stopBrowsingForPeers()
                self.onConnectionChanged?(true)
            case .notConnected:
                self.connectedPeerName = nil
                self.isConnected = false
                self.onConnectionChanged?(false)
            case .connecting:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = MultiplayerMessage.decoded(from: data) else { return }
        Task { @MainActor in
            self.onMessageReceived?(message)
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

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {}
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

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {}
}
