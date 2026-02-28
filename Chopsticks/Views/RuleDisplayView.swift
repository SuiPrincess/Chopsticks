import SwiftUI

struct RuleDisplayView: View {
    let config: GameConfig
    let isPreGame: Bool
    let onStart: (() -> Void)?
    let onDismiss: () -> Void

    init(config: GameConfig, isPreGame: Bool = false, onStart: (() -> Void)? = nil, onDismiss: @escaping () -> Void) {
        self.config = config
        self.isPreGame = isPreGame
        self.onStart = onStart
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            AppTheme.bgDark.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Image(systemName: "book.fill")
                                .font(.title2)
                                .foregroundStyle(AppTheme.accentGradient)
                            Text(isPreGame ? "ルール確認" : "ルール")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                    }
                    .padding(.top, 8)

                    // Basic rules
                    ruleSection(title: "基本ルール", items: basicRuleItems)

                    // Death rule
                    ruleSection(title: "死亡ルール", items: deathRuleItems)

                    // Active optional rules
                    let active = activeOptionalRules
                    if !active.isEmpty {
                        ruleSection(title: "追加ルール (ON)", items: active)
                    }

                    // Inactive rules
                    let inactive = inactiveOptionalRules
                    if !inactive.isEmpty {
                        ruleSection(title: "追加ルール (OFF)", items: inactive, dimmed: true)
                    }

                    // Buttons
                    if isPreGame {
                        Button(action: { onStart?() }) {
                            Text("ゲーム開始")
                        }
                        .buttonStyle(GlassButtonStyle())
                        .padding(.top, 8)
                    }
                }
                .padding(24)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(20)
        }
    }

    // MARK: - Basic rules
    private var basicRuleItems: [RuleItem] {
        var items = [
            RuleItem(icon: "hand.raised.fill", text: "各プレイヤーは\(config.handCount)本の手、指1本ずつでスタート"),
            RuleItem(icon: "hand.point.up.left.fill", text: "自分の手を選んでから、相手の手をタップして攻撃"),
            RuleItem(icon: "plus", text: "叩かれた手に、攻撃側の指の本数が加算される"),
            RuleItem(icon: "xmark.circle.fill", text: "全ての手が死んだプレイヤーの負け"),
        ]
        if config.handCount == 3 {
            items.insert(RuleItem(icon: "hand.raised.fingers.spread", text: "3本手モード: 通常より多い手で戦略的に!"), at: 1)
        }
        return items
    }

    // MARK: - Death rule items
    private var deathRuleItems: [RuleItem] {
        if config.isOverflowWrapEnabled {
            return [
                RuleItem(icon: "arrow.trianglehead.2.clockwise", text: "5を超えたら余りからカウント (例: 3+4=7→2)"),
                RuleItem(icon: "flame.fill", text: "ちょうど5になったら死亡"),
            ]
        } else {
            return [
                RuleItem(icon: "flame.fill", text: "5以上になったら即死亡 (クラシック)"),
            ]
        }
    }

    // MARK: - Optional rules
    private var activeOptionalRules: [RuleItem] {
        var items: [RuleItem] = []
        if config.isSplittingEnabled {
            items.append(RuleItem(icon: "arrow.left.arrow.right", text: "分割: 攻撃の代わりに両手の指を再分配できる"))
        }
        if config.isDeadHandRevivalEnabled {
            items.append(RuleItem(icon: "heart.fill", text: "復活: 分割で死亡した手を復活させられる"))
        }
        if config.isPoisonEnabled {
            items.append(RuleItem(icon: "drop.fill", text: "毒: 指1本の攻撃で相手の手を即死"))
        }
        if config.isBombEnabled {
            items.append(RuleItem(icon: "flame.circle.fill", text: "爆弾: 手が4になると爆発し全他の手に1ダメージ"))
        }
        if config.isMirrorEnabled {
            items.append(RuleItem(icon: "arrow.uturn.backward", text: "ミラー: 攻撃した分が自分にも加算"))
        }
        if config.isDoubleTapEnabled {
            items.append(RuleItem(icon: "hand.tap.fill", text: "ダブルタップ: 1ターンに2回攻撃可能"))
        }
        return items
    }

    private var inactiveOptionalRules: [RuleItem] {
        var items: [RuleItem] = []
        if !config.isSplittingEnabled {
            items.append(RuleItem(icon: "arrow.left.arrow.right", text: "分割"))
        }
        if !config.isDeadHandRevivalEnabled {
            items.append(RuleItem(icon: "heart.fill", text: "復活"))
        }
        if !config.isPoisonEnabled {
            items.append(RuleItem(icon: "drop.fill", text: "毒"))
        }
        if !config.isBombEnabled {
            items.append(RuleItem(icon: "flame.circle.fill", text: "爆弾"))
        }
        if !config.isMirrorEnabled {
            items.append(RuleItem(icon: "arrow.uturn.backward", text: "ミラー"))
        }
        if !config.isDoubleTapEnabled {
            items.append(RuleItem(icon: "hand.tap.fill", text: "ダブルタップ"))
        }
        return items
    }

    // MARK: - Section builder
    @ViewBuilder
    private func ruleSection(title: String, items: [RuleItem], dimmed: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(dimmed ? .white.opacity(0.3) : AppTheme.accent)
                .tracking(1)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(dimmed ? .white.opacity(0.2) : AppTheme.accent.opacity(0.8))
                            .frame(width: 20)
                        Text(item.text)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(dimmed ? .white.opacity(0.3) : .white.opacity(0.8))
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial.opacity(dimmed ? 0.3 : 1))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppTheme.glassBorder, lineWidth: 0.5)
                )
        )
    }
}

private struct RuleItem: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
}
