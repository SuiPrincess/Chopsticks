import SwiftUI

struct GameView: View {
    @State private var viewModel: GameViewModel
    @State private var showQuitConfirm = false
    @Environment(\.dismiss) private var dismiss

    init(config: GameConfig) {
        _viewModel = State(initialValue: GameViewModel(config: config))
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
                    isAI: viewModel.isVsAI,
                    isAIThinking: viewModel.isAIThinking,
                    onHandTapped: { viewModel.handleHandTap($0) },
                    onSplitTapped: { viewModel.showSplitPanel = true }
                )
                // AI対戦時は回転しない（対面プレイ不要）
                .rotationEffect(.degrees(viewModel.isVsAI ? 0 : 180))

                // Center bar
                ZStack {
                    DividerLineView(isPlayer1Turn: viewModel.isPlayer1Turn)

                    HStack {
                        Button {
                            showQuitConfirm = true
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.5))
                                .frame(width: 30, height: 30)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                                )
                        }

                        Spacer()

                        Button {
                            viewModel.showRules = true
                        } label: {
                            Image(systemName: "book")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.5))
                                .frame(width: 30, height: 30)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                                )
                        }
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
                    onHandTapped: { viewModel.handleHandTap($0) },
                    onSplitTapped: { viewModel.showSplitPanel = true }
                )
            }
            .ignoresSafeArea()

            if viewModel.showSplitPanel {
                let color = viewModel.isPlayer1Turn ? AppTheme.player1Color : AppTheme.player2Color
                SplitControlView(viewModel: viewModel, playerColor: color)
            }

            if viewModel.isGameOver {
                GameOverView(viewModel: viewModel, onDismiss: { dismiss() })
            }
        }
        .statusBarHidden()
        .sheet(isPresented: $viewModel.showRules) {
            RuleDisplayView(
                config: viewModel.config,
                onDismiss: { viewModel.showRules = false }
            )
            .presentationDetents([.large])
        }
        .alert("ゲームをやめますか？", isPresented: $showQuitConfirm) {
            Button("やめる", role: .destructive) { dismiss() }
            Button("続ける", role: .cancel) {}
        }
    }
}
