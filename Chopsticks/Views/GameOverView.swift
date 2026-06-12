import SwiftUI
import StoreKit

struct GameOverView: View {
    let viewModel: GameViewModel
    let onDismiss: () -> Void

    @State private var appeared = false
    @State private var confetti: [ConfettiPiece] = []
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()

            // Confetti
            ForEach(confetti) { piece in
                RoundedRectangle(cornerRadius: 2)
                    .fill(piece.color)
                    .frame(width: piece.size.width, height: piece.size.height)
                    .rotationEffect(.degrees(piece.rotation))
                    .offset(piece.offset)
                    .opacity(piece.opacity)
            }

            VStack(spacing: 28) {
                // Trophy
                if humanLostToAI {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.white.opacity(0.3))
                } else {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(AppTheme.goldGradient)
                        .shadow(color: .yellow.opacity(0.5), radius: 16)
                }

                VStack(spacing: 8) {
                    Text(humanLostToAI ? "LOSE..." : (viewModel.winnerName ?? ""))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(humanLostToAI ? .white.opacity(0.7) : .white)

                    Text(humanLostToAI ? "もう一回挑戦しよう" : "WIN!")
                        .font(.system(size: humanLostToAI ? 14 : 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(humanLostToAI
                            ? AnyShapeStyle(Color.white.opacity(0.5))
                            : AnyShapeStyle(AppTheme.accentGradient))
                        .tracking(humanLostToAI ? 1 : 6)

                    if viewModel.isPerfectWin && !humanLostToAI {
                        Text("💯 PERFECT!")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppTheme.goldGradient)
                            .tracking(2)
                    }

                    if viewModel.didRankUp {
                        Text("⬆️ RANK UP! 次は Lv.\(GameStats.shared.rankLevel)")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(.orange)
                            .tracking(1)
                    }
                }

                VStack(spacing: 6) {
                    Text("\(viewModel.state.turnCount) turns")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))

                    if viewModel.isVsAI {
                        statsLines
                    }
                }

                VStack(spacing: 12) {
                    Button(humanLostToAI ? "リベンジ!" : "Play Again") {
                        viewModel.newGame()
                    }
                    .buttonStyle(GlassButtonStyle())

                    Button("Menu") {
                        onDismiss()
                    }
                    .buttonStyle(GlassButtonStyle(isPrimary: false))

                    if !humanLostToAI && viewModel.isVsAI {
                        ShareLink(item: shareText) {
                            Label("結果を自慢する", systemImage: "square.and.arrow.up")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 40)
            }
            .scaleEffect(appeared ? 1 : 0.5)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(Anim.gameOver) { appeared = true }
            if !humanLostToAI {
                spawnConfetti()
                requestReviewIfDeserved()
            }
        }
    }

    private var shareText: String {
        let stats = GameStats.shared
        if let beatenLevel = viewModel.config.aiLevel {
            return "割り箸バトルでCPU Lv.\(beatenLevel)を撃破！現在ランクLv.\(stats.rankLevel) 🔥 #Chopsticks"
        }
        if stats.currentStreak >= 2 {
            return "割り箸バトルでCPUに\(stats.currentStreak)連勝中！🔥 #Chopsticks"
        }
        return "割り箸バトルでCPUに勝利！✌️ #Chopsticks"
    }

    /// 「気分が良い瞬間」だけレビューを依頼する（バージョンごとに1回）
    private func requestReviewIfDeserved() {
        let stats = GameStats.shared
        guard stats.shouldRequestReview() else { return }
        stats.markReviewRequested()
        Task { @MainActor in
            // 勝利演出が落ち着いてから出す
            try? await Task.sleep(for: .seconds(2))
            requestReview()
        }
    }

    private var humanLostToAI: Bool {
        viewModel.isVsAI && viewModel.winner?.id == viewModel.state.player2.id
    }

    @ViewBuilder
    private var statsLines: some View {
        let stats = GameStats.shared
        if stats.currentStreak >= 2 {
            Text("🔥 \(stats.currentStreak)連勝中!")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.orange)
        }
        if stats.didSetNewRecord {
            Text("✨ 自己ベスト更新!")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.yellow)
        }
        Text("通算 \(stats.wins)勝 \(stats.losses)敗・ベスト連勝 \(stats.bestStreak)")
            .font(.system(size: 12, design: .rounded))
            .foregroundStyle(.white.opacity(0.4))
    }

    private func spawnConfetti() {
        let colors: [Color] = [.red, .yellow, .green, .blue, .pink, .orange, .cyan, .purple]
        confetti = (0..<40).map { _ in
            ConfettiPiece(
                color: colors.randomElement()!,
                size: CGSize(width: CGFloat.random(in: 6...12), height: CGFloat.random(in: 10...20)),
                rotation: .random(in: 0...360),
                offset: CGSize(
                    width: CGFloat.random(in: -30...30),
                    height: CGFloat.random(in: -100...(-50))
                ),
                opacity: 1
            )
        }

        withAnimation(.easeOut(duration: 2.0)) {
            confetti = confetti.map { p in
                var new = p
                new.offset = CGSize(
                    width: CGFloat.random(in: -200...200),
                    height: CGFloat.random(in: 200...500)
                )
                new.rotation += .random(in: 180...720)
                new.opacity = 0
                return new
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            confetti = []
        }
    }
}

struct ConfettiPiece: Identifiable {
    let id = UUID()
    var color: Color
    var size: CGSize
    var rotation: Double
    var offset: CGSize
    var opacity: Double
}
