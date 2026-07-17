import SwiftUI

/// 直前のゲームを1手ずつ再生するリプレイ画面
struct ReplayView: View {
    let replay: Replay

    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var isPlaying = false
    @State private var snapshots: [GameState]

    init(replay: Replay) {
        self.replay = replay
        _snapshots = State(initialValue: ReplaySimulator.snapshots(for: replay))
    }

    private var current: GameState { snapshots[index] }
    private var isAtEnd: Bool { index >= snapshots.count - 1 }

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundGradientView()

                VStack(spacing: 0) {
                    // 盤面（読み取り専用）
                    PlayerAreaView(
                        player: current.player2,
                        isCurrentTurn: isCurrentTurn(current.player2),
                        playerColor: AppTheme.player2Color,
                        selectedAttackerHandId: nil,
                        isSplittingEnabled: false,
                        isAttackPhase: false,
                        isPoisonEnabled: current.config.isPoisonEnabled,
                        onHandTapped: { _ in },
                        onSplitTapped: {}
                    )
                    .allowsHitTesting(false)

                    DividerLineView(
                        pointsToBottom: isCurrentTurn(current.player1),
                        accentColor: isCurrentTurn(current.player1)
                            ? AppTheme.player1Color
                            : AppTheme.player2Color
                    )
                    .frame(height: 44)

                    PlayerAreaView(
                        player: current.player1,
                        isCurrentTurn: isCurrentTurn(current.player1),
                        playerColor: AppTheme.player1Color,
                        selectedAttackerHandId: nil,
                        isSplittingEnabled: false,
                        isAttackPhase: false,
                        isPoisonEnabled: current.config.isPoisonEnabled,
                        onHandTapped: { _ in },
                        onSplitTapped: {}
                    )
                    .allowsHitTesting(false)

                    controls
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                }
            }
            .navigationTitle("リプレイ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .task(id: isPlaying) {
                // 自動再生: 0.8秒ごとに1手進め、終端で停止する
                guard isPlaying else { return }
                while isPlaying && !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(800))
                    guard isPlaying, !Task.isCancelled else { return }
                    if isAtEnd {
                        isPlaying = false
                    } else {
                        step(1)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .environment(\.isReplayPlayback, true)
    }

    // MARK: - Controls

    @ViewBuilder
    private var controls: some View {
        VStack(spacing: 10) {
            Text("手 \(index)/\(snapshots.count - 1)")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.6))

            HStack(spacing: 24) {
                Button {
                    isPlaying = false
                    index = 0
                } label: {
                    Image(systemName: "backward.end.fill")
                }
                .disabled(index == 0)
                .accessibilityLabel("最初へ")

                Button {
                    isPlaying = false
                    step(-1)
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.system(size: 34))
                }
                .disabled(index == 0)
                .accessibilityLabel("前の手")

                Button {
                    if isAtEnd {
                        index = 0
                    }
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(AppTheme.accentGradient)
                }
                .accessibilityLabel(isPlaying ? "一時停止" : "再生")

                Button {
                    isPlaying = false
                    step(1)
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 34))
                }
                .disabled(isAtEnd)
                .accessibilityLabel("次の手")

                Button {
                    isPlaying = false
                    index = snapshots.count - 1
                } label: {
                    Image(systemName: "forward.end.fill")
                }
                .disabled(isAtEnd)
                .accessibilityLabel("最後へ")
            }
            .font(.system(size: 20))
            .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(AppTheme.glassBorder, lineWidth: 0.5)
                )
        )
    }

    private func isCurrentTurn(_ player: Player) -> Bool {
        guard case .playing = current.phase else { return false }
        return current.currentPlayerId == player.id
    }

    private func step(_ delta: Int) {
        let next = index + delta
        guard snapshots.indices.contains(next) else { return }
        withAnimation(Anim.finger) {
            index = next
        }
    }
}
