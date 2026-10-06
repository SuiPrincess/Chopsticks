import SwiftUI

struct SplitControlView: View {
    @Bindable var viewModel: GameViewModel
    let playerColor: Color

    @State private var distribution: [Int]
    @State private var appeared = false

    private var currentPlayer: Player { viewModel.currentPlayer }
    private var handCount: Int { currentPlayer.hands.count }
    private var allowRevival: Bool { viewModel.config.isDeadHandRevivalEnabled }
    private var isValid: Bool {
        currentPlayer.isValidSplit(newDistribution: distribution, allowRevival: allowRevival)
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
                .accessibilityHidden(true)

            VStack(spacing: 22) {
                Text("指を分割")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                Text("攻撃のかわりに、指を手の間で動かします")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)

                // Preview
                HStack(spacing: 16) {
                    ForEach(0..<handCount, id: \.self) { i in
                        splitPreview(count: distribution[i], label: handLabel(i))
                    }
                }
                .accessibilityHidden(true)

                // Steppers
                VStack(spacing: 8) {
                    ForEach(0..<handCount, id: \.self) { i in
                        HStack(spacing: 12) {
                            Text(handLabel(i))
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 56, alignment: .leading)

                            stepButton(systemName: "minus.circle.fill", enabled: canDecrease(i), label: "\(handLabel(i))の指を1本減らす") {
                                adjust(i, by: -1)
                            }

                            Text("\(distribution[i])")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(width: 32)
                                .accessibilityLabel("\(handLabel(i)) \(distribution[i])本")

                            stepButton(systemName: "plus.circle.fill", enabled: canIncrease(i), label: "\(handLabel(i))の指を1本増やす") {
                                adjust(i, by: 1)
                            }
                        }
                    }
                }

                // 無効な理由・警告（決定が押せない理由を必ず説明する）
                if let hint = hintText {
                    Label(hint.text, systemImage: hint.icon)
                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                        .foregroundStyle(hint.color)
                        .multilineTextAlignment(.center)
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
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(AppTheme.glassBorder, lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 24)
            .scaleEffect(appeared ? 1 : 0.8)
            .opacity(appeared ? 1 : 0)
        }
        .accessibilityAddTraits(.isModal)
        .onAppear {
            withAnimation(Anim.splitPanel) { appeared = true }
        }
    }

    // MARK: - Validation hints

    private struct Hint {
        let text: String
        let icon: String
        let color: Color
    }

    private var hintText: Hint? {
        let current = currentPlayer.hands.map(\.fingerCount)
        if distribution == current { return nil }  // まだ何も動かしていない
        if distribution.sorted() == current.sorted() {
            return Hint(text: "並べ替えだけの分割はできません", icon: "info.circle", color: .white.opacity(0.6))
        }
        for (i, hand) in currentPlayer.hands.enumerated() {
            if hand.isAlive && distribution[i] == 0 {
                return Hint(text: "生きている手を0本にはできません", icon: "exclamationmark.circle", color: .yellow)
            }
            if !hand.isAlive && distribution[i] > 0 && !allowRevival {
                return Hint(text: "死んだ手には配れません（復活ルールがOFF）", icon: "exclamationmark.circle", color: .yellow)
            }
        }
        // 爆弾ルールでは4本にした手が即爆発するため事前に警告
        if viewModel.config.isBombEnabled && distribution.contains(4) {
            return Hint(text: "4本にした手は分割直後に爆発します！", icon: "flame.fill", color: .orange)
        }
        return nil
    }

    // MARK: - Editing

    private func canDecrease(_ index: Int) -> Bool {
        distribution[index] > 0 && transferTarget(from: index, delta: -1) != nil
    }

    private func canIncrease(_ index: Int) -> Bool {
        distribution[index] < 4 && transferTarget(from: index, delta: 1) != nil
    }

    /// indexの手をdelta増減したとき、反対側で逆に増減できる手
    private func transferTarget(from index: Int, delta: Int) -> Int? {
        let newValue = distribution[index] + delta
        guard newValue >= 0, newValue <= 4 else { return nil }
        for other in 0..<handCount where other != index {
            let otherNew = distribution[other] - delta
            if otherNew >= 0 && otherNew <= 4 { return other }
        }
        return nil
    }

    private func adjust(_ index: Int, by delta: Int) {
        guard let other = transferTarget(from: index, delta: delta) else { return }
        distribution[index] += delta
        distribution[other] -= delta
    }

    private func handLabel(_ index: Int) -> String {
        if handCount == 2 {
            return index == 0 ? "左手" : "右手"
        }
        return "手\(index + 1)"
    }

    private func stepButton(systemName: String, enabled: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2)
                .foregroundStyle(enabled ? playerColor : .white.opacity(0.2))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .disabled(!enabled)
        .accessibilityLabel(label)
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
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}
