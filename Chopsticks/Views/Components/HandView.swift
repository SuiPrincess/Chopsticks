import SwiftUI

struct HandView: View {
    let hand: Hand
    let accentColor: Color
    let isSelected: Bool
    let isInteractable: Bool
    /// 次の相手の攻撃でこの手が死にうる（ルールに基づいて親が判定する）
    let isInDanger: Bool
    let accessibilityName: String
    let accessibilityHint: String
    let onTap: () -> Void
    var compact: Bool = false
    /// 毒ルール有効時、この手の攻撃が毒（相討ち即死）になることを示す
    var showsPoisonBadge: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title) private var sizeScale: CGFloat = 1
    @State private var showDeath = false
    @State private var previousAlive = true

    private var scale: CGFloat { min(sizeScale, 1.25) }
    private var cardWidth: CGFloat { (compact ? 80 : 105) * scale }
    private var cardHeight: CGFloat { (compact ? 110 : 140) * scale }
    private var fingerHeight: CGFloat { compact ? 32 : 40 }
    private var fingerWidth: CGFloat { compact ? 11 : 14 }
    private var countFont: CGFloat { compact ? 22 : 28 }
    private var cornerRadius: CGFloat { compact ? 18 : 22 }

    private var showsDanger: Bool { hand.isAlive && isInDanger }

    private var strokeColor: Color {
        if isSelected { return accentColor.opacity(0.8) }
        if showsDanger { return .red.opacity(0.7) }
        return AppTheme.glassBorder
    }

    private var accessibilityValueText: String {
        guard hand.isAlive else { return "死亡" }
        var text = "指\(hand.fingerCount)本"
        if showsDanger { text += "、危険。次の攻撃で死にます" }
        if isSelected { text += "、選択中" }
        return text
    }

    var body: some View {
        Button {
            if isInteractable { onTap() }
        } label: {
            card
        }
        .buttonStyle(.plain)
        .opacity(isInteractable || isSelected ? 1.0 : (hand.isAlive ? 0.72 : 0.4))
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(Anim.finger, value: hand.fingerCount)
        .animation(Anim.finger, value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityName)
        .accessibilityValue(accessibilityValueText)
        .accessibilityHint(isInteractable ? accessibilityHint : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityRemoveTraits(isInteractable ? [] : .isButton)
        .task(id: showDeath) {
            guard showDeath else { return }
            try? await Task.sleep(for: .seconds(1))
            showDeath = false
        }
        .onChange(of: hand.isAlive) { _, alive in
            if previousAlive && !alive {
                showDeath = true
                HapticManager.handDeath()
            }
            previousAlive = alive
        }
    }

    private var card: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            strokeColor,
                            style: StrokeStyle(
                                lineWidth: isSelected ? 2 : (showsDanger ? 2 : 0.5),
                                // 色だけに頼らないよう、危険は破線でも示す
                                dash: showsDanger && !isSelected ? [6, 3] : []
                            )
                        )
                )
                .glowPulse(isActive: isSelected, color: accentColor)
                .glowPulse(isActive: showsDanger && !isSelected, color: .red)

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
                        .foregroundStyle(showsDanger ? Color(red: 1.0, green: 0.45, blue: 0.45) : .white)
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
        .overlay(alignment: .topLeading) {
            if showsDanger {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: compact ? 12 : 14))
                    .foregroundStyle(.red)
                    .padding(compact ? 6 : 8)
            } else if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: compact ? 12 : 14))
                    .foregroundStyle(accentColor)
                    .padding(compact ? 6 : 8)
            }
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
