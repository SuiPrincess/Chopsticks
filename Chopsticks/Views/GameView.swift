import SwiftUI

struct GameView: View {
    @State private var viewModel: GameViewModel
    @State private var showQuitConfirm = false
    @State private var shakePhase: CGFloat = 0
    @State private var bannerEvent: BattleEvent?
    @AppStorage("tutorial.completed") private var tutorialCompleted = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var multiplayerService: (any MultiplayerService)?

    init(
        config: GameConfig,
        multiplayerService: (any MultiplayerService)? = nil,
        savedGame: SavedGame? = nil
    ) {
        _viewModel = State(initialValue: GameViewModel(config: config, restoring: savedGame))
        self.multiplayerService = multiplayerService
    }

    /// マルチプレイ/AI時は回転しない（対面プレイ不要）
    private var shouldRotatePlayer2: Bool {
        !viewModel.isVsAI && !viewModel.isMultiplayer
    }

    var body: some View {
        ZStack {
            BackgroundGradientView()

            VStack(spacing: 0) {
                // Player 2 (top)
                PlayerAreaView(
                    player: viewModel.state.player2,
                    isCurrentTurn: !viewModel.isPlayer1Turn,
                    playerColor: AppTheme.player2Color,
                    selectedAttackerHandId: viewModel.selectedAttackerHandId,
                    isSplittingEnabled: viewModel.config.isSplittingEnabled,
                    isAttackPhase: viewModel.isPlayer1Turn && viewModel.selectedAttackerHandId != nil,
                    isPoisonEnabled: viewModel.config.isPoisonEnabled,
                    isAI: viewModel.isVsAI,
                    isAIThinking: viewModel.isAIThinking,
                    hintedHandIds: hintedHandIds,
                    onHandTapped: { viewModel.handleHandTap($0) },
                    onSplitTapped: { viewModel.showSplitPanel = true }
                )
                .rotationEffect(.degrees(shouldRotatePlayer2 ? 180 : 0))

                // Center bar
                ZStack {
                    DividerLineView(isPlayer1Turn: viewModel.isPlayer1Turn)

                    HStack(spacing: 8) {
                        Button {
                            showQuitConfirm = true
                        } label: {
                            centerBarIcon("xmark")
                        }
                        .accessibilityLabel("ゲームをやめる")

                        // ヒント（CPU戦の自分の手番のみ）
                        if viewModel.isVsAI {
                            Button {
                                viewModel.requestHint()
                            } label: {
                                centerBarIcon(
                                    "lightbulb",
                                    tint: viewModel.hintAction != nil ? .yellow : nil
                                )
                            }
                            .disabled(viewModel.isAITurn || viewModel.isGameOver)
                            .opacity(viewModel.isAITurn ? 0.3 : 1)
                            .accessibilityLabel("ヒントを表示")
                        }

                        Spacer()

                        // マルチプレイ時: 待機インジケーター / それ以外: ターン数
                        if viewModel.isMultiplayer && viewModel.isRemoteControlled {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .tint(.white.opacity(0.5))
                                    .scaleEffect(0.6)
                                Text("相手のターン")
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        } else if !viewModel.isGameOver {
                            Text("ターン \(min(viewModel.state.turnCount + 1, GameViewModel.turnLimit))/\(GameViewModel.turnLimit)")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(
                                    viewModel.state.turnCount >= GameViewModel.turnLimit - 10
                                        ? .yellow.opacity(0.9)
                                        : .white.opacity(0.35)
                                )
                                // 中央のターン矢印サークルの直下に置く
                                .offset(y: 25)
                        }

                        Spacer()

                        Button {
                            viewModel.showRules = true
                        } label: {
                            centerBarIcon("book")
                        }
                        .accessibilityLabel("ルールを表示")
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: 44)

                // Player 1 (bottom)
                PlayerAreaView(
                    player: viewModel.state.player1,
                    isCurrentTurn: viewModel.isPlayer1Turn,
                    playerColor: AppTheme.player1Color,
                    selectedAttackerHandId: viewModel.selectedAttackerHandId,
                    isSplittingEnabled: viewModel.config.isSplittingEnabled,
                    isAttackPhase: !viewModel.isPlayer1Turn && viewModel.selectedAttackerHandId != nil,
                    isPoisonEnabled: viewModel.config.isPoisonEnabled,
                    hintedHandIds: hintedHandIds,
                    onHandTapped: { viewModel.handleHandTap($0) },
                    onSplitTapped: { viewModel.showSplitPanel = true }
                )
            }
            .ignoresSafeArea()
            .modifier(ShakeEffect(animatableData: shakePhase))

            if let event = bannerEvent {
                BattleEventBanner(event: event)
                    .id(event.id)
            }

            // 初プレイのコーチマーク（最初の2手番だけ）
            if showsTutorialHint {
                TutorialHintView(text: tutorialHintText)
                    .rotationEffect(.degrees(!viewModel.isVsAI && !viewModel.isPlayer1Turn ? 180 : 0))
                    .offset(y: !viewModel.isVsAI && !viewModel.isPlayer1Turn ? -90 : 90)
            }

            if viewModel.showSplitPanel {
                let color = viewModel.isPlayer1Turn ? AppTheme.player1Color : AppTheme.player2Color
                SplitControlView(viewModel: viewModel, playerColor: color)
                    // 対面プレイではPlayer 2側に向ける
                    .rotationEffect(.degrees(!viewModel.isVsAI && !viewModel.isPlayer1Turn ? 180 : 0))
            }

            if viewModel.isGameOver {
                GameOverView(viewModel: viewModel, onDismiss: {
                    if viewModel.isMultiplayer {
                        viewModel.disconnectMultiplayer()
                    }
                    dismiss()
                })
            }
        }
        .statusBarHidden()
        .onChange(of: viewModel.state.turnCount) { _, count in
            if count >= 2 { tutorialCompleted = true }
        }
        .onChange(of: viewModel.shakeTrigger) { _, _ in
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 0.4)) { shakePhase += 1 }
        }
        .onChange(of: viewModel.battleEvent) { _, event in
            guard let event else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                bannerEvent = event
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                if bannerEvent?.id == event.id {
                    withAnimation(.easeOut(duration: 0.3)) { bannerEvent = nil }
                }
            }
        }
        .sheet(isPresented: $viewModel.showRules) {
            RuleDisplayView(
                config: viewModel.config,
                onDismiss: { viewModel.showRules = false }
            )
            .presentationDetents([.large])
        }
        .alert("ゲームをやめますか？", isPresented: $showQuitConfirm) {
            Button("やめる", role: .destructive) {
                if viewModel.isMultiplayer {
                    viewModel.disconnectMultiplayer()
                }
                dismiss()
            }
            Button("続ける", role: .cancel) {}
        } message: {
            if !viewModel.isMultiplayer && !viewModel.isGameOver {
                Text("進行中のゲームは自動保存され、メニューの「続きから」で再開できます")
            }
        }
        .alert("接続が切れました", isPresented: $viewModel.showDisconnectAlert) {
            Button("OK") { dismiss() }
        }
        .onAppear {
            if let service = multiplayerService {
                viewModel.setupMultiplayer(service: service)
                viewModel.startMultiplayerGame(
                    asHost: service.isHost,
                    opponentName: service.opponentName
                )
            }
            // 復元したゲームがCPUの手番で中断されていた場合に再開する
            viewModel.triggerAITurn()
        }
    }

    /// ヒントで光らせる手（タップ提案の攻撃側＋対象）
    private var hintedHandIds: Set<UUID> {
        guard case .tap(let attackerId, let targetId)? = viewModel.hintAction else { return [] }
        return [attackerId, targetId]
    }

    @ViewBuilder
    private func centerBarIcon(_ systemName: String, tint: Color? = nil) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(tint ?? .white.opacity(0.5))
            .frame(width: 30, height: 30)
            .background(
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
            )
    }

    private var showsTutorialHint: Bool {
        !tutorialCompleted
            && viewModel.state.turnCount < 2
            && !viewModel.isAITurn
            && !viewModel.isGameOver
            && !viewModel.showSplitPanel
    }

    private var tutorialHintText: String {
        viewModel.selectedAttackerHandId == nil
            ? "① 自分の手をタップしてえらぶ"
            : "② 相手の手をタップしてこうげき！"
    }
}

/// 初プレイ時のコーチマーク
private struct TutorialHintView: View {
    let text: String
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 14))
            Text(text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
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
        .allowsHitTesting(false)
        .onAppear {
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
            .foregroundStyle(event.color)
            .shadow(color: event.color.opacity(0.8), radius: 14)
            .shadow(color: event.color.opacity(0.4), radius: 30)
            .transition(.scale(scale: 0.3).combined(with: .opacity))
            .allowsHitTesting(false)
    }
}
