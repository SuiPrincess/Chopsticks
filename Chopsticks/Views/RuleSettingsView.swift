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
                                ruleLabel("分割", desc: "攻撃の代わりに両手の指を再分配できる")
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
                                ruleLabel("毒", desc: "指1本の攻撃で相手の手を即死。ただし毒を使った手も死ぬ（相討ち）")
                            }
                            .tint(.green)
                        }

                        ruleCard {
                            Toggle(isOn: $config.isBombEnabled) {
                                ruleLabel("爆弾", desc: "手がちょうど4になると爆発、全他の手に1ダメージ")
                            }
                            .tint(.orange)
                        }

                        ruleCard {
                            Toggle(isOn: $config.isMirrorEnabled) {
                                ruleLabel("ミラー", desc: "攻撃後、自分の手にも同じ数が加算される")
                            }
                            .tint(.cyan)
                        }

                        ruleCard {
                            Toggle(isOn: $config.isDoubleTapEnabled) {
                                ruleLabel("ダブルタップ", desc: "1ターンに2回攻撃できる")
                            }
                            .tint(.purple)
                        }
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

    // MARK: - Components
    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.accent.opacity(0.7))
                .tracking(1)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func ruleLabel(_ title: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text(desc)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
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
