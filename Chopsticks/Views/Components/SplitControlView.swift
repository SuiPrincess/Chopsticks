import SwiftUI

struct SplitControlView: View {
    @Bindable var viewModel: GameViewModel
    let playerColor: Color

    @State private var distribution: [Int]
    @State private var appeared = false

    private var currentPlayer: Player { viewModel.currentPlayer }
    private var total: Int { currentPlayer.totalFingers }
    private var handCount: Int { currentPlayer.hands.count }
    private var isValid: Bool {
        let allowRevival = viewModel.config.isDeadHandRevivalEnabled
        return currentPlayer.isValidSplit(newDistribution: distribution, allowRevival: allowRevival)
    }

    init(viewModel: GameViewModel, playerColor: Color) {
        self.viewModel = viewModel
        self.playerColor = playerColor
        let player = viewModel.currentPlayer
        _distribution = State(initialValue: player.hands.map(\.fingerCount))
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { viewModel.showSplitPanel = false }

            VStack(spacing: 24) {
                Text("Split")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                // Preview
                HStack(spacing: 16) {
                    ForEach(0..<handCount, id: \.self) { i in
                        splitPreview(count: distribution[i], label: handLabel(i))
                    }
                }

                // Steppers
                VStack(spacing: 12) {
                    ForEach(0..<handCount, id: \.self) { i in
                        HStack(spacing: 16) {
                            Text(handLabel(i))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 24)

                            Button { adjust(i, by: -1) } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(distribution[i] > 0 ? playerColor : .white.opacity(0.2))
                            }
                            .disabled(distribution[i] <= 0)

                            Text("\(distribution[i])")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(width: 28)

                            Button { adjust(i, by: 1) } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(distribution[i] < 4 ? playerColor : .white.opacity(0.2))
                            }
                            .disabled(distribution[i] >= 4)
                        }
                    }
                }

                // Total
                let currentTotal = distribution.reduce(0, +)
                Text("合計: \(currentTotal) / \(total)")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(currentTotal == total ? .white.opacity(0.5) : .red)

                // 爆弾ルールでは4本にした手が即爆発するため事前に警告
                if viewModel.config.isBombEnabled && distribution.contains(4) {
                    Label("4本にした手は分割直後に爆発します！", systemImage: "flame.fill")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.orange)
                }

                // Buttons
                HStack(spacing: 12) {
                    Button("キャンセル") {
                        viewModel.showSplitPanel = false
                    }
                    .buttonStyle(GlassButtonStyle(color: .white.opacity(0.3), isPrimary: false))

                    Button("決定") {
                        viewModel.performSplit(newDistribution: distribution)
                    }
                    .buttonStyle(GlassButtonStyle(color: playerColor))
                    .disabled(!isValid)
                    .opacity(isValid ? 1 : 0.4)
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(AppTheme.glassBorder, lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 32)
            .scaleEffect(appeared ? 1 : 0.8)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(Anim.splitPanel) { appeared = true }
        }
    }

    private func adjust(_ index: Int, by delta: Int) {
        let newVal = distribution[index] + delta
        guard newVal >= 0, newVal <= 4 else { return }
        let others = (0..<handCount).filter { $0 != index }
        for other in others {
            let otherNew = distribution[other] - delta
            if otherNew >= 0 && otherNew <= 4 {
                distribution[index] = newVal
                distribution[other] = otherNew
                return
            }
        }
    }

    private func handLabel(_ index: Int) -> String {
        if handCount == 2 {
            return index == 0 ? "L" : "R"
        }
        return "\(index + 1)"
    }

    @ViewBuilder
    private func splitPreview(count: Int, label: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(i < count ? playerColor : Color.white.opacity(0.1))
                        .frame(width: 8, height: i < count ? 24 : 14)
                }
            }
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}
