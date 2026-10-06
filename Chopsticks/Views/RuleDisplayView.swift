import SwiftUI

struct RuleDisplayView: View {
    let config: GameConfig
    let isPreGame: Bool
    let title: String?
    let onStart: (() -> Void)?
    let onDismiss: () -> Void

    init(
        config: GameConfig,
        isPreGame: Bool = false,
        title: String? = nil,
        onStart: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.config = config
        self.isPreGame = isPreGame
        self.title = title
        self.onStart = onStart
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            AppTheme.bgDark.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Image(systemName: "book.fill")
                                .font(.title2)
                                .foregroundStyle(AppTheme.accentGradient)
                            Text(title ?? (isPreGame ? "ルール確認" : "ルール"))
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                        }
                        Spacer()
                    }
                    .padding(.top, 8)

                    ruleSection(title: "基本ルール", items: basicRuleItems)
                    ruleSection(title: "死亡ルール", items: deathRuleItems)

                    let active = activeOptionalRules
                    if !active.isEmpty {
                        ruleSection(title: "追加ルール（ON）", items: active)
                    }

                    // 対戦前は「いま使わないルール」を出さず、開始ボタンまでの距離を縮める
                    let inactive = inactiveOptionalRules
                    if !isPreGame && !inactive.isEmpty {
                        ruleSection(title: "追加ルール（OFF）", items: inactive, dimmed: true)
                    }
                }
                .padding(24)
                .padding(.top, 20)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .padding(8)
            .accessibilityLabel("閉じる")
        }
        .safeAreaInset(edge: .bottom) {
            if isPreGame {
                Button(action: { onStart?() }) {
                    Text("ゲーム開始")
                }
                .buttonStyle(GlassButtonStyle())
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(AppTheme.bgDark.opacity(0.92))
            }
        }
    }

    // MARK: - Basic rules
    private var basicRuleItems: [RuleItem] {
        var items = [
            RuleItem(icon: "hand.raised.fill", text: "各プレイヤーは\(config.handCount)本の手、指1本ずつでスタート"),
            RuleItem(icon: "hand.point.up.left.fill", text: "自分の手を選んでから、相手の手をタップして攻撃"),
            RuleItem(icon: "plus", text: "叩かれた手に、攻撃した手の指の本数が足される"),
            RuleItem(icon: "xmark.circle.fill", text: "全ての手が死んだプレイヤーの負け"),
            RuleItem(icon: "hourglass", text: "\(GameState.turnLimit)ターンで決着しない場合は判定（生きている手の数 → 指が少ない方の勝ち）"),
        ]
        if config.handCount == 3 {
            items.insert(RuleItem(icon: "hand.raised.fingers.spread", text: "3本手モード: 通常より多い手で戦略的に！"), at: 1)
        }
        return items
    }

    // MARK: - Death rule items
    private var deathRuleItems: [RuleItem] {
        var items: [RuleItem]
        if config.isOverflowWrapEnabled {
            items = [
                RuleItem(icon: "arrow.triangle.2.circlepath", text: "5を超えたら余りから数え直す（例: 3+4=7 → 2）"),
                RuleItem(icon: "flame.fill", text: "ちょうど5になったら死亡"),
            ]
        } else {
            items = [
                RuleItem(icon: "flame.fill", text: "5以上になったら即死亡（クラシック）"),
            ]
        }
        items.append(RuleItem(icon: "exclamationmark.triangle.fill", text: "赤く光る手は、次の攻撃で死んでしまうサイン"))
        return items
    }

    // MARK: - Optional rules
    private var activeOptionalRules: [RuleItem] {
        var items: [RuleItem] = []
        if config.isSplittingEnabled {
            items.append(RuleItem(icon: "arrow.left.arrow.right", text: "分割: 攻撃のかわりに指を手の間で動かせる（自分の手を0本にはできない）"))
        }
        if config.isSplittingEnabled && config.isDeadHandRevivalEnabled {
            items.append(RuleItem(icon: "heart.fill", text: "復活: 分割で、死んだ手に指を配って復活させられる"))
        }
        if config.isPoisonEnabled {
            items.append(RuleItem(icon: "drop.fill", text: "毒: 指1本の手で、指2本以上の相手の手を攻撃すると即死。ただし毒を使った手も死ぬ（相討ち）"))
        }
        if config.isBombEnabled {
            items.append(RuleItem(icon: "flame.circle.fill", text: "爆弾: 手がちょうど4本になると爆発して死に、他の全ての手に1ダメージ（連鎖あり）"))
        }
        if config.isMirrorEnabled {
            items.append(RuleItem(icon: "arrow.uturn.backward", text: "ミラー: 攻撃した本数が自分の手にも足される"))
        }
        if config.isDoubleTapEnabled {
            items.append(RuleItem(icon: "hand.tap.fill", text: "ダブルタップ: 1ターンに2回攻撃できる"))
        }
        return items
    }

    private var inactiveOptionalRules: [RuleItem] {
        var items: [RuleItem] = []
        if !config.isSplittingEnabled { items.append(RuleItem(icon: "arrow.left.arrow.right", text: "分割")) }
        if !(config.isSplittingEnabled && config.isDeadHandRevivalEnabled) { items.append(RuleItem(icon: "heart.fill", text: "復活")) }
        if !config.isPoisonEnabled { items.append(RuleItem(icon: "drop.fill", text: "毒")) }
        if !config.isBombEnabled { items.append(RuleItem(icon: "flame.circle.fill", text: "爆弾")) }
        if !config.isMirrorEnabled { items.append(RuleItem(icon: "arrow.uturn.backward", text: "ミラー")) }
        if !config.isDoubleTapEnabled { items.append(RuleItem(icon: "hand.tap.fill", text: "ダブルタップ")) }
        return items
    }

    // MARK: - Section builder
    @ViewBuilder
    private func ruleSection(title: String, items: [RuleItem], dimmed: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(dimmed ? .white.opacity(0.3) : AppTheme.accent)
                .tracking(1)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(dimmed ? .white.opacity(0.2) : AppTheme.accent.opacity(0.8))
                            .frame(width: 20)
                            .accessibilityHidden(true)
                        Text(item.text)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(dimmed ? .white.opacity(0.35) : .white.opacity(0.85))
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
