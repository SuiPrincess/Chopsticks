import SwiftUI

/// アプリ設定（サウンド・ハプティクス）
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = SettingsStore.shared
    @AppStorage("tutorial.completed") private var tutorialCompleted = false
    @State private var didResetTutorial = false
    @State private var showShop = false
    @State private var showNotificationDenied = false

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            ZStack {
                AppTheme.bgDark.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        settingCard {
                            Toggle(isOn: $settings.isSoundEnabled) {
                                settingLabel(
                                    "サウンド",
                                    desc: "効果音を再生する（サイレントスイッチに従う）",
                                    icon: "speaker.wave.2.fill"
                                )
                            }
                            .tint(AppTheme.accent)
                            .onChange(of: settings.isSoundEnabled) { _, enabled in
                                if enabled { SoundManager.play(.tap) }
                            }
                        }

                        settingCard {
                            Toggle(isOn: $settings.isHapticsEnabled) {
                                settingLabel(
                                    "ハプティクス",
                                    desc: "タップ・撃破時などの振動フィードバック",
                                    icon: "iphone.radiowaves.left.and.right"
                                )
                            }
                            .tint(AppTheme.accent)
                            .onChange(of: settings.isHapticsEnabled) { _, enabled in
                                if enabled { HapticManager.handSelect() }
                            }
                        }

                        settingCard {
                            Toggle(isOn: reminderBinding) {
                                settingLabel(
                                    "デイリーリマインダー",
                                    desc: "毎日19:30、連続プレイ日数が途切れる前にお知らせ",
                                    icon: "bell.badge.fill"
                                )
                            }
                            .tint(AppTheme.accent)
                        }

                        settingCard {
                            Button {
                                showShop = true
                            } label: {
                                HStack {
                                    settingLabel(
                                        "ショップ・カラーテーマ",
                                        desc: "プレミアムでテーマ解放＆ヒント無制限",
                                        icon: "crown.fill"
                                    )
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.white.opacity(0.3))
                                }
                            }
                        }

                        settingCard {
                            Button {
                                tutorialCompleted = false
                                didResetTutorial = true
                            } label: {
                                HStack {
                                    settingLabel(
                                        "チュートリアルをもう一度見る",
                                        desc: "次のゲーム開始時に操作ガイドを表示",
                                        icon: "graduationcap.fill"
                                    )
                                    Spacer()
                                    if didResetTutorial {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                            .disabled(didResetTutorial)
                        }

                        Text("Chopsticks（割り箸） v\(appVersion)")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.white.opacity(0.3))
                            .padding(.top, 12)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .sheet(isPresented: $showShop) {
                ShopView()
                    .presentationDetents([.large])
            }
            .alert("通知が許可されていません", isPresented: $showNotificationDenied) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("設定アプリ > Chopsticks > 通知 から許可してください")
            }
        }
        .preferredColorScheme(.dark)
    }

    /// リマインダートグル: ONにする時は通知許可を取ってから反映する
    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { settings.isDailyReminderEnabled },
            set: { enabled in
                if enabled {
                    Task { @MainActor in
                        let granted = await NotificationManager.enableDailyReminder()
                        SettingsStore.shared.isDailyReminderEnabled = granted
                        if !granted {
                            showNotificationDenied = true
                        }
                    }
                } else {
                    NotificationManager.disableDailyReminder()
                    SettingsStore.shared.isDailyReminderEnabled = false
                }
            }
        )
    }

    // MARK: - Components

    @ViewBuilder
    private func settingLabel(_ title: String, desc: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(desc)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    @ViewBuilder
    private func settingCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
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
