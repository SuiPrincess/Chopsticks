import SwiftUI

struct GameView: View {
    @State private var viewModel: GameViewModel
    @State private var settings = AppSettings.shared
    @State private var showQuitConfirm = false
    @State private var shakePhase: CGFloat = 0
    @State private var bannerEvent: BattleEvent?
    @State private var showsGameOver = false
    @AppStorage("tutorial.completed") private var tutorialCompleted = false
    @AppStorage("tutorial.reachSeen") private var reachSeen = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private let multiplayerService: (any MultiplayerService)?

    private static let reachHintText = "赤く光る手は、次の攻撃で死んでしまうサイン！"

    init(config: GameConfig, multiplayerService: (any MultiplayerService)? = nil) {
        _viewModel = State(initialValue: GameViewModel(config: config))
        self.multiplayerService = multiplayerService
    }

    /// 中断した対戦を続きから再開する
    init(savedGame: SavedGame) {
        _viewModel = State(initialValue: GameViewModel(savedGame: savedGame))
        self.multiplayerService = nil
    }

    private var reducesMotion: Bool { systemReduceMotion || settings.reducesEffects }

    /// 1台を向かい合わせで使う2人対戦だけ、上側のプレイヤーを逆向きにする
    private var rotatesTopPlayer: Bool { !viewModel.isVsAI && !viewModel.isMultiplayer }

    /// 上側プレイヤーの手番で、パネルを上側に向けるか
    private var rotatesActiveOverlay: Bool { rotatesTopPlayer && !viewModel.isBottomPlayerTurn }

    private var turnLabel: String {
        let player = viewModel.isBottomPlayerTurn ? viewModel.bottomPlayer : viewModel.topPlayer
        return "\(player.name)のターン"
    }

    var body: some View {
        ZStack {
            BackgroundGradientView()

            VStack(spacing: 0) {
                // 上側のプレイヤー
                PlayerAreaView(
                    player: viewModel.topPlayer,
                    isCurrentTurn: !viewModel.isBottomPlayerTurn,
                    playerColor: AppTheme.player2Color,
                    selectedAttackerHandId: viewModel.selectedAttackerHandId,
                    isAttackPhase: viewModel.isBottomPlayerTurn && viewModel.selectedAttackerHandId != nil,
                    isInputEnabled: viewModel.isHumanTurn,
                    canSplit: viewModel.canSplitNow && viewModel.isHumanTurn && !viewModel.isBottomPlayerTurn,
                    reservesSplitSlot: viewModel.config.isSplittingEnabled,
                    threatenedHandIds: viewModel.threatenedHandIds,
                    isPoisonEnabled: viewModel.config.isPoisonEnabled,
                    isAI: viewModel.isVsAI,
                    isAIThinking: viewModel.isAIThinking,
                    onHandTapped: { viewModel.handleHandTap($0) },
                    onSplitTapped: { viewModel.showSplitPanel = true }
                )
                .rotationEffect(.degrees(rotatesTopPlayer ? 180 : 0))

                centerBar

                // 下側のプレイヤー（マルチプレイでは常に自分）
                PlayerAreaView(
                    player: viewModel.bottomPlayer,
                    isCurrentTurn: viewModel.isBottomPlayerTurn,
                    playerColor: AppTheme.player1Color,
                    selectedAttackerHandId: viewModel.selectedAttackerHandId,
                    isAttackPhase: !viewModel.isBottomPlayerTurn && viewModel.selectedAttackerHandId != nil,
                    isInputEnabled: viewModel.isHumanTurn,
                    canSplit: viewModel.canSplitNow && viewModel.isHumanTurn && viewModel.isBottomPlayerTurn,
                    reservesSplitSlot: viewModel.config.isSplittingEnabled,
                    threatenedHandIds: viewModel.threatenedHandIds,
                    isPoisonEnabled: viewModel.config.isPoisonEnabled,
                    isAI: false,
                    isAIThinking: false,
                    onHandTapped: { viewModel.handleHandTap($0) },
                    onSplitTapped: { viewModel.showSplitPanel = true }
                )
            }
            .modifier(ShakeEffect(animatableData: shakePhase))

            if let event = bannerEvent {
                BattleEventBanner(event: event)
                    .id(event.id)
            }

            if let hint = coachHint {
                CoachHintView(text: hint, pulses: !reducesMotion)
                    .rotationEffect(.degrees(rotatesActiveOverlay ? 180 : 0))
                    .offset(y: rotatesActiveOverlay ? -96 : 96)
            }

            if viewModel.showSplitPanel {
                SplitControlView(
                    viewModel: viewModel,
                    playerColor: viewModel.isBottomPlayerTurn ? AppTheme.player1Color : AppTheme.player2Color
                )
                .rotationEffect(.degrees(rotatesActiveOverlay ? 180 : 0))
            }

            if viewModel.isWaitingForHost && !viewModel.isGameOver {
                WaitingOverlay(text: "ホストの準備を待っています…") {
                    viewModel.leaveMultiplayer()
                    dismiss()
                }
            }

            if showsGameOver {
                GameOverView(viewModel: viewModel, onDismiss: { dismiss() })
                    .transition(.opacity)
            }
        }
        .statusBarHidden()
        // 最後の一撃の演出（シェイク・破片・バナー）を見せてから結果を出す
        .task(id: viewModel.isGameOver) {
            if viewModel.isGameOver {
                try? await Task.sleep(for: .seconds(reducesMotion ? 0.25 : 0.95))
                guard !Task.isCancelled else { return }
                withAnimation(Anim.gameOver) { showsGameOver = true }
            } else {
                showsGameOver = false
            }
        }
        .task(id: bannerEvent?.id) {
            guard bannerEvent != nil else { return }
            try? await Task.sleep(for: .seconds(1.0))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { bannerEvent = nil }
        }
        .onChange(of: viewModel.state.turnCount) { _, count in
            if count >= 2 { tutorialCompleted = true }
        }
        .onChange(of: viewModel.shakeTrigger) { _, _ in
            guard !reducesMotion else { return }
            withAnimation(.linear(duration: 0.4)) { shakePhase += 1 }
        }
        .onChange(of: viewModel.battleEvent) { _, event in
            guard let event else { return }
            withAnimation(reducesMotion ? .easeOut(duration: 0.15) : .spring(response: 0.3, dampingFraction: 0.55)) {
                bannerEvent = event
            }
            AccessibilityNotification.Announcement(event.text).post()
        }
        .onChange(of: viewModel.isBottomPlayerTurn) { _, _ in
            if !viewModel.isGameOver {
                AccessibilityNotification.Announcement(turnLabel).post()
            }
        }
        .onChange(of: reachHintVisible) { old, new in
            if old && !new { reachSeen = true }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { viewModel.handleAppBackgrounded() }
        }
        .sheet(isPresented: $viewModel.showRules) {
            RuleDisplayView(
                config: viewModel.config,
                onDismiss: { viewModel.showRules = false }
            )
            .presentationDetents([.large])
        }
        .alert(quitTitle, isPresented: $showQuitConfirm) {
            if canSuspend {
                Button("あとで続ける") {
                    viewModel.suspendGame()
                    dismiss()
                }
            }
            Button(quitDestructiveLabel, role: .destructive) {
                if viewModel.isMultiplayer {
                    viewModel.leaveMultiplayer()
                } else {
                    viewModel.abandonGame()
                }
                dismiss()
            }
            Button("続ける", role: .cancel) {}
        } message: {
            Text(quitMessage)
        }
        .onChange(of: viewModel.notice) { _, notice in
            // 通知を確実に出すため、開いているルールシートは閉じる
            if notice != nil { viewModel.showRules = false }
        }
        .alert(
            viewModel.notice?.title ?? "通知",
            isPresented: Binding(
                // 他のアラートやシートが閉じるまで待ってから出す
                get: { viewModel.notice != nil && !viewModel.showRules && !showQuitConfirm },
                set: { if !$0 { viewModel.notice = nil } }
            ),
            presenting: viewModel.notice
        ) { notice in
            if notice == .rematchTimedOut {
                Button("OK", role: .cancel) {}
            } else {
                Button("メニューへ") {
                    viewModel.disconnectMultiplayer()
                    dismiss()
                }
            }
        } message: { notice in
            Text(notice.message)
        }
        .onAppear {
            if let service = multiplayerService {
                viewModel.setupMultiplayer(service: service)
            }
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
            // ボタン以外の経路で画面が閉じられても、相手を待たせないよう対戦から抜ける（二重呼び出しは無害）
            if viewModel.isMultiplayer { viewModel.leaveMultiplayer() }
        }
    }

    // MARK: - Center bar

    private var centerBar: some View {
        ZStack {
            DividerLineView(isBottomTurn: viewModel.isBottomPlayerTurn, turnLabel: turnLabel)

            HStack {
                CircleIconButton(systemName: "xmark", label: "ゲームをやめる") {
                    showQuitConfirm = true
                }

                // 中央は手番インジケーターの場所なので、ターン表示は左に寄せる
                turnCounter

                Spacer()

                CircleIconButton(systemName: "book", label: "ルールを見る") {
                    viewModel.showRules = true
                }
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 52)
    }

    @ViewBuilder
    private var turnCounter: some View {
        let current = min(viewModel.state.turnCount + 1, GameViewModel.turnLimit)
        let isLate = viewModel.turnsRemaining <= 10
        VStack(spacing: 1) {
            if viewModel.isMultiplayer && viewModel.isRemoteControlled && !viewModel.isGameOver {
                HStack(spacing: 4) {
                    ProgressView()
                        .tint(.white.opacity(0.5))
                        .scaleEffect(0.55)
                    Text("相手のターン")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            Text("ターン \(current)/\(GameViewModel.turnLimit)")
                .font(.system(.caption2, design: .rounded, weight: isLate ? .bold : .regular))
                .foregroundStyle(isLate ? Color.yellow : .white.opacity(0.4))
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("ターン\(current)、上限\(GameViewModel.turnLimit)。上限に達すると判定です")
    }

    // MARK: - Quit

    private var canSuspend: Bool { !viewModel.isMultiplayer && !viewModel.isGameOver }

    private var isRankedInProgress: Bool {
        viewModel.config.isRanked && viewModel.state.turnCount > 0
    }

    private var quitTitle: String {
        if viewModel.isMultiplayer { return "対戦をやめますか？" }
        return isRankedInProgress ? "ランク戦を中断しますか？" : "ゲームをやめますか？"
    }

    private var quitMessage: String {
        if viewModel.isMultiplayer { return "やめると、相手の対戦も終了します。" }
        if isRankedInProgress {
            return "「あとで続ける」なら、続きから再開できます。破棄するとこの対戦は負けになります。"
        }
        return "「あとで続ける」なら、続きから再開できます。"
    }

    private var quitDestructiveLabel: String {
        if viewModel.isMultiplayer { return "やめる" }
        return isRankedInProgress ? "破棄して負けにする" : "破棄する"
    }

    // MARK: - Coach marks

    private var reachHintVisible: Bool {
        tutorialCompleted && !reachSeen
            && !viewModel.threatenedHandIds.isEmpty
            && viewModel.isHumanTurn && !viewModel.showSplitPanel && !viewModel.isGameOver
    }

    private var coachHint: String? {
        guard !viewModel.isGameOver, viewModel.isHumanTurn, !viewModel.showSplitPanel else { return nil }
        if !tutorialCompleted && viewModel.state.turnCount < 2 {
            return viewModel.selectedAttackerHandId == nil
                ? "① 自分の手をタップしてえらぶ"
                : "② 相手の手をタップしてこうげき！"
        }
        if reachHintVisible { return Self.reachHintText }
        return nil
    }
}

/// 初プレイ時などのコーチマーク
private struct CoachHintView: View {
    let text: String
    let pulses: Bool
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 14))
            Text(text)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().stroke(AppTheme.accent.opacity(0.5), lineWidth: 1))
        )
        .shadow(color: AppTheme.accent.opacity(0.4), radius: 10)
        .scaleEffect(pulse ? 1.04 : 1.0)
        .padding(.horizontal, 16)
        .allowsHitTesting(false)
        .onAppear {
            guard pulses else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

/// 画面中央に弾けるように出るイベントテキスト
private struct BattleEventBanner: View {
    let event: BattleEvent

    var body: some View {
        Text(event.text)
            .font(.system(size: 42, weight: .black, design: .rounded))
            .italic()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, 24)
            .foregroundStyle(event.color)
            .shadow(color: event.color.opacity(0.8), radius: 14)
            .shadow(color: event.color.opacity(0.4), radius: 30)
            .transition(.scale(scale: 0.3).combined(with: .opacity))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// 相手の準備待ちなどで盤面の上に出す待機表示
private struct WaitingOverlay: View {
    let text: String
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.3)
                Text(text)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Button("やめる", action: onCancel)
                    .buttonStyle(GlassButtonStyle(isPrimary: false))
                    .padding(.horizontal, 80)
            }
            .padding(24)
        }
        .accessibilityAddTraits(.isModal)
    }
}
