import SwiftUI

struct HandView: View {
    let hand: Hand
    let accentColor: Color
    let isSelected: Bool
    let isInteractable: Bool
    let onTap: () -> Void
    var compact: Bool = false
    /// 毒ルール有効時、この手の攻撃が毒（相討ち即死）になることを示す
    var showsPoisonBadge: Bool = false
    /// ヒント対象の手（黄色く光る）
    var isHinted: Bool = false
    /// VoiceOver用の説明（例: "Player 1の手、指2本"）
    var accessibilityText: String = ""
    /// iPadなどの広い画面での拡大率
    var sizeScale: CGFloat = 1

    @State private var showDeath = false
    @State private var previousAlive = true

    private var cardWidth: CGFloat { (compact ? 80 : 105) * sizeScale }
    private var cardHeight: CGFloat { (compact ? 110 : 140) * sizeScale }
    private var fingerHeight: CGFloat { (compact ? 32 : 40) * sizeScale }
    private var fingerWidth: CGFloat { (compact ? 11 : 14) * sizeScale }
    private var countFont: CGFloat { (compact ? 22 : 28) * sizeScale }

    /// リーチ状態（あと一撃で死亡しうる）
    private var isInDanger: Bool { hand.isAlive && hand.fingerCount == 4 }

    private var strokeColor: Color {
        if isSelected { return accentColor.opacity(0.8) }
        if isHinted { return .yellow.opacity(0.7) }
        if isInDanger { return .red.opacity(0.6) }
        return AppTheme.glassBorder
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: compact ? 18 : 22)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: compact ? 18 : 22)
                        .stroke(
                            strokeColor,
                            lineWidth: isSelected ? 2 : (isInDanger ? 1.5 : 0.5)
                        )
                )
                .glowPulse(isActive: isSelected, color: accentColor)
                .glowPulse(isActive: isHinted && !isSelected, color: .yellow)
                .glowPulse(isActive: isInDanger && !isSelected && !isHinted, color: .red)

            if hand.isAlive {
                VStack(spacing: compact ? 6 : 10) {
                    HStack(spacing: compact ? 3 : 5) {
                        ForEach(0..<4, id: \.self) { i in
                            fingerCapsule(index: i)
                        }
                    }
                    .padding(.top, 4)

                    Text("\(hand.fingerCount)")
                        .font(.system(size: countFont, weight: .bold, design: .rounded))
                        .foregroundStyle(isInDanger ? Color(red: 1.0, green: 0.45, blue: 0.45) : .white)
                        .contentTransition(.numericText(value: Double(hand.fingerCount)))
                }
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "xmark")
                        .font(.system(size: compact ? 24 : 32, weight: .bold))
                        .foregroundStyle(.white.opacity(0.2))
                    Text("0")
                        .font(.system(size: compact ? 16 : 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.2))
                }
            }

            ParticleExplosionView(isActive: showDeath, color: accentColor)
        }
        .frame(width: cardWidth, height: cardHeight)
        .overlay(alignment: .topTrailing) {
            if showsPoisonBadge && hand.isAlive {
                Text("☠️")
                    .font(.system(size: compact ? 12 : 15))
                    .padding(compact ? 5 : 7)
            }
        }
        .opacity(isInteractable || isSelected ? 1.0 : (hand.isAlive ? 0.7 : 0.4))
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(Anim.finger, value: hand.fingerCount)
        .animation(Anim.finger, value: isSelected)
        .onTapGesture {
            if isInteractable { onTap() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText.isEmpty
            ? (hand.isAlive
                ? String(localized: "手、指\(hand.fingerCount)本")
                : String(localized: "手、死亡"))
            : accessibilityText)
        .accessibilityAddTraits(isInteractable ? .isButton : [])
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onChange(of: hand.isAlive) { _, alive in
            if previousAlive && !alive {
                showDeath = true
                HapticManager.handDeath()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    showDeath = false
                }
            }
            previousAlive = alive
        }
    }

    @ViewBuilder
    private func fingerCapsule(index: Int) -> some View {
        let isActive = index < hand.fingerCount
        Capsule()
            .fill(
                isActive
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    : AnyShapeStyle(Color.white.opacity(0.1))
            )
            .frame(width: fingerWidth, height: isActive ? fingerHeight : fingerHeight * 0.55)
            .shadow(color: isActive ? accentColor.opacity(0.5) : .clear, radius: 5)
            .animation(
                .spring(response: 0.35, dampingFraction: 0.6).delay(Double(index) * 0.05),
                value: hand.fingerCount
            )
    }
}
