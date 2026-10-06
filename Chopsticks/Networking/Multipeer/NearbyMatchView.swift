import SwiftUI
import MultipeerConnectivity

@Observable
@MainActor
final class NearbyMatchState {
    enum Phase { case rolePick, hosting, browsing, connecting }

    var phase: Phase = .rolePick
    var service: MultipeerService?
    /// 検索開始からしばらく誰も見つからないときのヒント表示
    var showsSearchHint = false
    private var hintTask: Task<Void, Never>?

    var discoveredPeers: [MCPeerID] { service?.discoveredPeers ?? [] }
    var invitationFrom: String? { service?.receivedInvitation?.from.displayName }
    var errorMessage: String? { service?.lastError }

    func startHosting(onConnected: @escaping (MultipeerService) -> Void) {
        let svc = MultipeerService(displayName: AppSettings.shared.nickname, isHost: true)
        setupCallbacks(svc, onConnected: onConnected)
        service = svc
        phase = .hosting
        svc.startAdvertising()
        startHintTimer()
    }

    func startBrowsing(onConnected: @escaping (MultipeerService) -> Void) {
        let svc = MultipeerService(displayName: AppSettings.shared.nickname, isHost: false)
        setupCallbacks(svc, onConnected: onConnected)
        service = svc
        phase = .browsing
        svc.startBrowsing()
        startHintTimer()
    }

    func cancel() {
        hintTask?.cancel()
        showsSearchHint = false
        service?.stop()
        service = nil
        phase = .rolePick
    }

    func acceptInvitation() {
        phase = .connecting
        service?.acceptInvitation()
    }

    func declineInvitation() {
        service?.declineInvitation()
    }

    func invitePeer(_ peer: MCPeerID) {
        phase = .connecting
        service?.invitePeer(peer)
    }

    private func setupCallbacks(_ svc: MultipeerService, onConnected: @escaping (MultipeerService) -> Void) {
        svc.onConnectionChanged = { [weak self, weak svc] connected in
            guard let self, let svc else { return }
            if connected {
                self.hintTask?.cancel()
                // 接続後のコールバックはゲーム画面側が引き継ぐ
                svc.onConnectionChanged = nil
                onConnected(svc)
            } else {
                // 接続失敗・拒否: 役割選択画面に戻さず、同じ画面で再試行できるようにする
                self.phase = svc.isHost ? .hosting : .browsing
            }
        }
    }

    private func startHintTimer() {
        hintTask?.cancel()
        showsSearchHint = false
        hintTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled else { return }
            self?.showsSearchHint = true
        }
    }
}

struct NearbyMatchView: View {
    let onConnected: (MultipeerService) -> Void
    let onCancel: () -> Void

    @State private var matchState = NearbyMatchState()
    @State private var settings = AppSettings.shared
    @State private var isEditingNickname = false
    @State private var nicknameDraft = ""

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
        .alert("ニックネーム", isPresented: $isEditingNickname) {
            TextField("ニックネーム", text: $nicknameDraft)
            Button("保存") {
                let trimmed = nicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { settings.nickname = String(trimmed.prefix(12)) }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("相手の画面に表示される名前です")
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
                Text("同じWi-Fi、またはBluetoothが有効な端末どうしで対戦できます")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                nicknameDraft = settings.nickname
                isEditingNickname = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle")
                    Text(settings.nickname)
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Capsule().fill(.ultraThinMaterial))
            }
            .accessibilityLabel("ニックネームを変更: \(settings.nickname)")

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
                .buttonStyle(GlassButtonStyle(isPrimary: false))
                .padding(.horizontal, 100)
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
                Text("「\(settings.nickname)」として公開中")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }

            ProgressView()
                .tint(AppTheme.accent)
                .scaleEffect(1.2)

            if let name = matchState.invitationFrom {
                invitationCard(from: name)
            }

            statusMessages(waitingText: "相手の端末で「部屋を探す」を選んでもらってください")

            cancelButton()
        }
    }

    @ViewBuilder
    private func invitationCard(from name: String) -> some View {
        VStack(spacing: 12) {
            Text("\(name) から対戦の申し込み")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                Button("対戦する") {
                    matchState.acceptInvitation()
                }
                .buttonStyle(GlassButtonStyle())

                Button("断る") {
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
                    Text("近くの端末を検索中...")
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
                        .accessibilityLabel("\(peer.displayName)に対戦を申し込む")
                    }
                }
                .padding(.horizontal, 24)
            }

            statusMessages(waitingText: "相手の端末で「部屋を作る」を選んでもらってください")

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
            cancelButton()
        }
    }

    @ViewBuilder
    private func statusMessages(waitingText: String) -> some View {
        VStack(spacing: 10) {
            if let error = matchState.errorMessage {
                VStack(spacing: 8) {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                    Button("設定を開く") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.accent)
                }
                .padding(.horizontal, 32)
            } else if matchState.showsSearchHint {
                Text(waitingText + "\n見つからないときは両方の端末でWi-FiとBluetoothをオンにし、ローカルネットワークを許可してください")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }

    @ViewBuilder
    private func cancelButton() -> some View {
        Button("キャンセル") {
            matchState.cancel()
        }
        .buttonStyle(GlassButtonStyle(isPrimary: false))
        .padding(.horizontal, 100)
    }
}
