import SwiftUI
import MultipeerConnectivity

@Observable
@MainActor
final class NearbyMatchState {
    enum Phase { case rolePick, hosting, browsing, connecting }

    var phase: Phase = .rolePick
    var discoveredPeers: [MCPeerID] = []
    var invitationFrom: String?
    var service: MultipeerService?

    func startHosting(onConnected: @escaping (MultipeerService) -> Void) {
        let svc = MultipeerService(displayName: UIDevice.current.name, isHost: true)
        setupCallbacks(svc, onConnected: onConnected)
        service = svc
        phase = .hosting
        svc.startAdvertising()
    }

    func startBrowsing(onConnected: @escaping (MultipeerService) -> Void) {
        let svc = MultipeerService(displayName: UIDevice.current.name, isHost: false)
        setupCallbacks(svc, onConnected: onConnected)
        service = svc
        phase = .browsing
        svc.startBrowsing()
    }

    func cancel() {
        service?.stop()
        service = nil
        discoveredPeers = []
        invitationFrom = nil
        phase = .rolePick
    }

    func acceptInvitation() {
        phase = .connecting
        service?.acceptInvitation()
    }

    func declineInvitation() {
        invitationFrom = nil
        service?.declineInvitation()
    }

    func invitePeer(_ peer: MCPeerID) {
        phase = .connecting
        service?.invitePeer(peer)
    }

    private func setupCallbacks(_ svc: MultipeerService, onConnected: @escaping (MultipeerService) -> Void) {
        svc.onConnectionChanged = { [weak self] connected in
            if connected { onConnected(svc) }
            else { self?.phase = .rolePick }
        }
        // Poll published properties via observation
        // Use a timer to sync published state from MultipeerService → Observable state
        Task { @MainActor [weak self] in
            while self?.service === svc {
                self?.discoveredPeers = svc.discoveredPeers
                if let invitation = svc.receivedInvitation {
                    self?.invitationFrom = invitation.from.displayName
                }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }
}

struct NearbyMatchView: View {
    @Binding var config: GameConfig
    let onConnected: (MultipeerService) -> Void
    let onCancel: () -> Void

    @State private var matchState = NearbyMatchState()

    var body: some View {
        ZStack {
            AppTheme.bgDark.ignoresSafeArea()

            switch matchState.phase {
            case .rolePick: rolePickerView
            case .hosting: hostView
            case .browsing: guestView
            case .connecting: connectingView
            }
        }
    }

    // MARK: - Role Picker
    @ViewBuilder
    private var rolePickerView: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 36))
                    .foregroundStyle(AppTheme.accentGradient)
                Text("近くの人と対戦")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 12) {
                Button {
                    matchState.startHosting(onConnected: onConnected)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.badge.shield.checkmark.fill")
                        Text("部屋を作る")
                    }
                }
                .buttonStyle(GlassButtonStyle())

                Button {
                    matchState.startBrowsing(onConnected: onConnected)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                        Text("部屋を探す")
                    }
                }
                .buttonStyle(GlassButtonStyle(color: AppTheme.accentSecondary))
            }
            .padding(.horizontal, 40)

            Button("戻る") { onCancel() }
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Host View
    @ViewBuilder
    private var hostView: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Image(systemName: "wifi")
                    .font(.system(size: 36))
                    .foregroundStyle(AppTheme.accentGradient)
                Text("対戦相手を待っています")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(UIDevice.current.name)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }

            ProgressView()
                .tint(AppTheme.accent)
                .scaleEffect(1.2)

            if let name = matchState.invitationFrom {
                invitationCard(from: name)
            }

            cancelButton()
        }
    }

    @ViewBuilder
    private func invitationCard(from name: String) -> some View {
        VStack(spacing: 12) {
            Text("\(name) から接続要求")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                Button("承認") {
                    matchState.acceptInvitation()
                }
                .buttonStyle(GlassButtonStyle())

                Button("拒否") {
                    matchState.declineInvitation()
                }
                .buttonStyle(GlassButtonStyle(isPrimary: false))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.accent.opacity(0.5), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
    }

    // MARK: - Guest View
    @ViewBuilder
    private var guestView: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 36))
                    .foregroundStyle(AppTheme.accentGradient)
                Text("部屋を探しています")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }

            if matchState.discoveredPeers.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                        .tint(AppTheme.accent)
                    Text("近くのデバイスを検索中...")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(matchState.discoveredPeers, id: \.self) { peer in
                        Button {
                            matchState.invitePeer(peer)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(AppTheme.accent)
                                Text(peer.displayName)
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                            .foregroundStyle(.white)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(AppTheme.glassBorder, lineWidth: 0.5)
                                    )
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)
            }

            cancelButton()
        }
    }

    // MARK: - Connecting View
    @ViewBuilder
    private var connectingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .tint(AppTheme.accent)
                .scaleEffect(1.5)
            Text("接続中...")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private func cancelButton() -> some View {
        Button("キャンセル") {
            matchState.cancel()
        }
        .font(.system(size: 14, design: .rounded))
        .foregroundStyle(.white.opacity(0.5))
    }
}
