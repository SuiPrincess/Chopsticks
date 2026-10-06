import SwiftUI

struct PlayerAreaView: View {
    let player: Player
    let isCurrentTurn: Bool
    let playerColor: Color
    let selectedAttackerHandId: UUID?
    /// このエリアの手が攻撃対象になっている（相手の手番で自分が選んだ手を持っている側ではなく、狙われる側）
    let isAttackPhase: Bool
    /// この端末の人間が今操作できる
    let isInputEnabled: Bool
    let canSplit: Bool
    /// 分割ルールが有効な間はボタン分の高さを常に確保し、手番が変わっても手の位置が動かないようにする
    let reservesSplitSlot: Bool
    let threatenedHandIds: Set<UUID>
    let isPoisonEnabled: Bool
    let isAI: Bool
    let isAIThinking: Bool
    let onHandTapped: (UUID) -> Void
    let onSplitTapped: () -> Void

    private var isCompact: Bool { player.hands.count > 2 }

    var body: some View {
        VStack(spacing: isCompact ? 10 : 16) {
            // Player label
            HStack(spacing: 6) {
                if isAI {
                    Image(systemName: "cpu")
                        .font(.system(size: 12))
                        .foregroundStyle(playerColor.opacity(0.7))
                }
                Text(player.name)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(isCurrentTurn ? playerColor : .white.opacity(0.4))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if isCurrentTurn {
                    Text("のターン")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(playerColor.opacity(0.8))
                }
                if isAI && isAIThinking && isCurrentTurn {
                    ProgressView()
                        .scaleEffect(0.5)
                        .tint(playerColor)
                }
            }
            .accessibilityElement(children: .combine)

            // Hands
            HStack(spacing: isCompact ? 16 : 32) {
                ForEach(Array(player.hands.enumerated()), id: \.element.id) { index, hand in
                    HandView(
                        hand: hand,
                        accentColor: playerColor,
                        isSelected: selectedAttackerHandId == hand.id,
                        isInteractable: handInteractable(hand),
                        isInDanger: threatenedHandIds.contains(hand.id),
                        accessibilityName: "\(player.name)の\(handName(index))",
                        accessibilityHint: isAttackPhase ? "ダブルタップでこの手を攻撃" : "ダブルタップで攻撃に使う手を選ぶ",
                        onTap: { onHandTapped(hand.id) },
                        compact: isCompact,
                        showsPoisonBadge: isPoisonEnabled && hand.fingerCount == 1 && isCurrentTurn
                    )
                }
            }

            // Split button
            if reservesSplitSlot {
                let isSplitVisible = canSplit && isCurrentTurn
                Button(action: onSplitTapped) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 13))
                        Text("分割")
                            .font(.system(.footnote, design: .rounded, weight: .medium))
                    }
                    .foregroundStyle(playerColor)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(playerColor.opacity(0.35), lineWidth: 0.5)
                            )
                    )
                }
                .opacity(isSplitVisible ? 1 : 0)
                .disabled(!isSplitVisible)
                .accessibilityHidden(!isSplitVisible)
                .accessibilityLabel("指を分割する")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 12)
    }

    private func handInteractable(_ hand: Hand) -> Bool {
        hand.isAlive && isInputEnabled && (isCurrentTurn || isAttackPhase)
    }

    private func handName(_ index: Int) -> String {
        if player.hands.count == 2 {
            return index == 0 ? "左の手" : "右の手"
        }
        return "\(index + 1)番目の手"
    }
}
