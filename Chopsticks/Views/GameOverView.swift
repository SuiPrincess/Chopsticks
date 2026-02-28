import SwiftUI

struct GameOverView: View {
    let viewModel: GameViewModel
    let onDismiss: () -> Void

    @State private var appeared = false
    @State private var confetti: [ConfettiPiece] = []

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
                Image(systemName: "trophy.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(AppTheme.goldGradient)
                    .shadow(color: .yellow.opacity(0.5), radius: 16)

                VStack(spacing: 8) {
                    Text(viewModel.winnerName ?? "")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("WIN!")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppTheme.accentGradient)
                        .tracking(6)
                }

                Text("\(viewModel.state.turnCount) turns")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))

                VStack(spacing: 12) {
                    Button("Play Again") {
                        viewModel.newGame()
                    }
                    .buttonStyle(GlassButtonStyle())

                    Button("Menu") {
                        onDismiss()
                    }
                    .buttonStyle(GlassButtonStyle(isPrimary: false))
                }
                .padding(.horizontal, 40)
            }
            .scaleEffect(appeared ? 1 : 0.5)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(Anim.gameOver) { appeared = true }
            spawnConfetti()
        }
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
