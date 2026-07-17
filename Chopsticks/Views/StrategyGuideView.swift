import SwiftUI

/// 攻略ガイド: 勝つための考え方をルール別に図解する
struct StrategyGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.bgDark.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        Text("ルールは単純でも、読み合いは奥深い。この7つの考え方を覚えるだけで勝率は大きく変わる。")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        guideCard("まず「5」を数える", icon: "plus.forwardslash.minus") {
                            paragraph("手は指が5本以上になると死ぬ。つまり「自分の指＋相手の指」が5以上になる組み合わせを見つければ倒せる。")
                            AttackDiagram(attacker: 3, target: 2, result: nil, caption: "3 + 2 = 5 💀")
                            paragraph("毎ターン最初に、倒せる手がないか全ての組み合わせを確認するクセをつけよう。")
                        }

                        guideCard("即死圏に気づく", icon: "exclamationmark.triangle.fill", tint: .orange) {
                            paragraph("同じ計算は相手もしてくる。自分の手が相手のどれかの指と合計5以上になるなら、次のターンに倒される。")
                            AttackDiagram(
                                attacker: 1, target: 4, result: nil,
                                attackerColor: AppTheme.player2Color,
                                targetColor: AppTheme.player1Color,
                                caption: "1 + 4 = 5 💀"
                            )
                            paragraph("特に指4本の手は、指1本にすら倒される最危険状態。放置しないこと。")
                        }

                        guideCard("分割で立て直す", icon: "arrow.left.arrow.right", tint: .cyan) {
                            paragraph("分割は攻撃を1回休む代わりに、指を両手へ配り直して危険な形をリセットできる。")
                            SplitDiagram(before: [4, 1], after: [3, 2], caption: "(4,1) → (3,2)")
                            paragraph("復活ルールがあるなら、死んだ手に指を分けて手数を取り戻そう。手の数の差は、そのまま選択肢の差になる。")
                        }

                        guideCard("ループは「ちょうど5」だけが死", icon: "arrow.triangle.2.circlepath", tint: .green) {
                            paragraph("ループルールでは5を超えた分は余りに戻る（3+4=7→2）。死ぬのは合計がちょうど5のときだけ。")
                            AttackDiagram(attacker: 4, target: 3, result: 2, caption: "4 + 3 = 7 → 2")
                            paragraph("大きく叩くと、相手をかえって安全な数に戻してしまうことがある。叩く前に必ず合計を計算しよう。")
                        }

                        guideCard("テンポで勝つ", icon: "bolt.fill", tint: .yellow) {
                            paragraph("倒せるときは基本すぐ倒す。手が減った相手は、攻撃も防御も選択肢が半分になる。")
                            paragraph("ただし倒した直後に自分が即死圏へ入るなら一呼吸。「この手のあと相手は何をしてくる？」を1手だけ先読みするだけで勝率は大きく変わる。")
                        }

                        guideCard("特殊ルールのコツ", icon: "sparkles", tint: .purple) {
                            tipRow("drop.fill", .green,
                                   "毒: 指1本の攻撃が即死になる相討ち技。自分の弱い手と相手の強い手を交換するのが基本。")
                            tipRow("flame.circle.fill", .red,
                                   "爆弾: 4になった手は爆発して他の全ての手に1ダメージ。自分の手を4で止めず、相手を4にして誘爆を狙おう。")
                            tipRow("arrow.uturn.backward", .cyan,
                                   "ミラー: 攻撃した指の数が自分の手にも加算される。大きく叩くほど自分も危険。小さく叩いて分割で整えるのが安全。")
                            tipRow("hand.tap.fill", .orange,
                                   "ダブルタップ: 1ターンに2回攻撃できる。1回目で相手を4に調整し、2回目で仕留めるコンボが強力。")
                        }

                        guideCard("ランク戦の心得", icon: "trophy.fill", tint: .orange) {
                            paragraph("上位のCPUは数手先まで読んでくる。攻撃の前に「相手の返しの一手」まで考えるクセをつけよう。")
                            paragraph("行き詰まったらヒントでAIの推奨手を見よう。「なぜその手なのか」を考えると、読み筋そのものが身につく。")
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("攻略ガイド")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Components

    @ViewBuilder
    private func guideCard<Content: View>(
        _ title: LocalizedStringKey,
        icon: String,
        tint: Color = AppTheme.accent,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppTheme.glassBorder, lineWidth: 0.5)
                )
        )
    }

    @ViewBuilder
    private func paragraph(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 14, design: .rounded))
            .foregroundStyle(.white.opacity(0.75))
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func tipRow(_ icon: String, _ color: Color, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color.opacity(0.9))
                .frame(width: 18)
                .padding(.top, 2)
            Text(text)
                .font(.system(size: 13.5, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Diagrams

/// 指の本数を示すミニ手表示（数字は翻訳不要のためverbatim）
private struct HandGlyph: View {
    let count: Int
    let color: Color
    var isDead: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(!isDead && i < count ? color.opacity(0.75) : Color.white.opacity(0.08))
                        .frame(width: 7, height: !isDead && i < count ? 22 : 12)
                }
            }
            Text(verbatim: isDead ? "💀" : "\(count)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(isDead ? .red.opacity(0.9) : .white.opacity(0.85))
        }
    }
}

/// 攻撃の結果を図解する: 攻撃手 + 相手の手 → 結果（nilなら死亡）
private struct AttackDiagram: View {
    let attacker: Int
    let target: Int
    let result: Int?
    var attackerColor: Color = AppTheme.player1Color
    var targetColor: Color = AppTheme.player2Color
    let caption: String

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                HandGlyph(count: attacker, color: attackerColor)
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                HandGlyph(count: target, color: targetColor)
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                if let result {
                    HandGlyph(count: result, color: targetColor)
                } else {
                    HandGlyph(count: 0, color: targetColor, isDead: true)
                }
            }
            Text(verbatim: caption)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
        // VoiceOverには数式キャプションだけを読み上げる（カプセル図は装飾）
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: caption))
    }
}

/// 分割の前後を図解する
private struct SplitDiagram: View {
    let before: [Int]
    let after: [Int]
    let caption: String

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                handPair(before)
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                handPair(after)
            }
            Text(verbatim: caption)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: caption))
    }

    private func handPair(_ counts: [Int]) -> some View {
        HStack(spacing: 12) {
            ForEach(Array(counts.enumerated()), id: \.offset) { _, count in
                HandGlyph(count: count, color: AppTheme.player1Color)
            }
        }
    }
}
