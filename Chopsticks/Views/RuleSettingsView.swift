import SwiftUI

struct RuleSettingsView: View {
    @Binding var config: GameConfig
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.bgDark.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        Label("ここで決めたルールは「2人対戦」「フリー対戦」「近くの人と対戦」「オンライン対戦」で使われます。ランク戦は標準ルール固定です。",
                              systemImage: "info.circle")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // --- 基本ルール ---
                        sectionHeader("基本ルール")

                        ruleCard {
                            Toggle(isOn: $config.isOverflowWrapEnabled) {
                                ruleLabel("オーバーフロー", desc: "5を超えたらループ、ちょうど5で死亡")
                            }
                            .tint(AppTheme.accent)
                        }

                        ruleCard {
                            Toggle(isOn: $config.isSplittingEnabled) {
                                ruleLabel("分割", desc: "攻撃のかわりに両手の指を再分配できる")
                            }
                            .tint(AppTheme.accent)
                        }

                        ruleCard {
                            Toggle(isOn: $config.isDeadHandRevivalEnabled) {
                                ruleLabel("復活", desc: "分割で死亡した手を復活させられる")
                            }
                            .tint(AppTheme.accent)
                            .disabled(!config.isSplittingEnabled)
                            .opacity(config.isSplittingEnabled ? 1 : 0.4)
                        }

                        // --- 手の数 ---
                        sectionHeader("手の数")

                        ruleCard {
                            VStack(alignment: .leading, spacing: 8) {
                                ruleLabel("プレイヤーの手", desc: "各プレイヤーの手の数を変更")
                                Picker("手の数", selection: $config.handCount) {
                                    Text("2本").tag(2)
                                    Text("3本").tag(3)
                                }
                                .pickerStyle(.segmented)
                            }
                        }

                        // --- 特殊ルール ---
                        sectionHeader("特殊ルール")

                        ruleCard {
                            Toggle(isOn: $config.isPoisonEnabled) {
                                ruleLabel("毒", desc: "指1本の手で指2本以上の手を攻撃すると即死。ただし毒を使った手も死ぬ（相討ち）")
                            }
                            .tint(.green)
                        }

                        ruleCard {
                            Toggle(isOn: $config.isBombEnabled) {
                                ruleLabel("爆弾", desc: "手がちょうど4本になると爆発、他の全ての手に1ダメージ")
                            }
                            .tint(.orange)
                        }

                        ruleCard {
                            Toggle(isOn: $config.isMirrorEnabled) {
                                ruleLabel("ミラー", desc: "攻撃後、自分の手にも同じ数が足される")
                            }
                            .tint(.cyan)
                        }

                        ruleCard {
                            Toggle(isOn: $config.isDoubleTapEnabled) {
                                ruleLabel("ダブルタップ", desc: "1ターンに2回攻撃できる")
                            }
                            .tint(.purple)
                        }

                        Button {
                            withAnimation(.spring(response: 0.3)) { resetToStandard() }
                        } label: {
                            Label("標準ルールに戻す", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(GlassButtonStyle(isPrimary: false))
                        .padding(.top, 8)
                    }
                    .padding(20)
                    .animation(.spring(response: 0.3), value: config)
                }
            }
            .navigationTitle("ルール設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }

    /// モードの設定（gameMode/aiDifficulty）は残し、ルールだけを標準に戻す
    private func resetToStandard() {
        let mode = config.gameMode
        let difficulty = config.aiDifficulty
        config = GameConfig()
        config.gameMode = mode
        config.aiDifficulty = difficulty
    }

    // MARK: - Components
    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.accent.opacity(0.8))
                .tracking(1)
            Spacer()
        }
        .padding(.top, 8)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func ruleLabel(_ title: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
            Text(desc)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    @ViewBuilder
    private func ruleCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.glassBorder, lineWidth: 0.5)
                )
        )
    }
}
