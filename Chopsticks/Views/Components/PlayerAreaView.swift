import SwiftUI

struct PlayerAreaView: View {
    let player: Player
    let isCurrentTurn: Bool
    let playerColor: Color
    let selectedAttackerHandId: UUID?
    let isSplittingEnabled: Bool
    let isAttackPhase: Bool
    let isAI: Bool
    let isAIThinking: Bool
    let onHandTapped: (UUID) -> Void
    let onSplitTapped: () -> Void

    init(
        player: Player,
        isCurrentTurn: Bool,
        playerColor: Color,
        selectedAttackerHandId: UUID?,
        isSplittingEnabled: Bool,
        isAttackPhase: Bool,
        isAI: Bool = false,
        isAIThinking: Bool = false,
        onHandTapped: @escaping (UUID) -> Void,
        onSplitTapped: @escaping () -> Void
    ) {
        self.player = player
        self.isCurrentTurn = isCurrentTurn
        self.playerColor = playerColor
        self.selectedAttackerHandId = selectedAttackerHandId
        self.isSplittingEnabled = isSplittingEnabled
        self.isAttackPhase = isAttackPhase
        self.isAI = isAI
        self.isAIThinking = isAIThinking
        self.onHandTapped = onHandTapped
        self.onSplitTapped = onSplitTapped
    }

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
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(isCurrentTurn ? playerColor : .white.opacity(0.35))
                    .tracking(2)
                    .textCase(.uppercase)
                if isAI && isAIThinking && isCurrentTurn {
                    ProgressView()
                        .scaleEffect(0.5)
                        .tint(playerColor)
                }
            }

            // Hands
            HStack(spacing: isCompact ? 16 : 32) {
                ForEach(player.hands) { hand in
                    HandView(
                        hand: hand,
                        accentColor: playerColor,
                        isSelected: selectedAttackerHandId == hand.id,
                        isInteractable: handInteractable(hand),
                        onTap: { onHandTapped(hand.id) },
                        compact: isCompact
                    )
                }
            }

            // Split button (hide for AI)
            if isCurrentTurn && isSplittingEnabled && !player.isDefeated && !isAI {
                Button(action: onSplitTapped) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 12))
                        Text("Split")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(playerColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(playerColor.opacity(0.3), lineWidth: 0.5)
                            )
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 20)
    }

    private func handInteractable(_ hand: Hand) -> Bool {
        guard hand.isAlive else { return false }
        if isAI && isCurrentTurn { return false }
        if isCurrentTurn && !isAttackPhase { return true }
        if isAttackPhase { return true }
        return false
    }
}
