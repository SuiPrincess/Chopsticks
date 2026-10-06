import SwiftUI
import UserNotifications

struct SettingsView: View {
    @State private var settings = AppSettings.shared
    @State private var stats = GameStats.shared
    @State private var gameCenter = GameCenterManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showResetConfirm = false
    @State private var showHowToPlay = false
    @State private var showNotificationDenied = false
    @State private var showHintsResetNotice = false

    var body: some View {
        NavigationStack {
            Form {
                Section("サウンドと演出") {
                    Toggle("効果音", isOn: $settings.isSoundEnabled)
                        .onChange(of: settings.isSoundEnabled) { _, enabled in
                            if enabled { SoundManager.shared.play(.select) }
                        }
                    Toggle("振動（ハプティクス）", isOn: $settings.isHapticsEnabled)
                        .onChange(of: settings.isHapticsEnabled) { _, enabled in
                            if enabled { HapticManager.handSelect() }
                        }
                    Toggle("演出をひかえめにする", isOn: $settings.reducesEffects)
                    Text("画面のゆれ・紙吹雪・光るアニメーションを抑えます。端末の「視差効果を減らす」がオンのときも自動でひかえめになります。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.white.opacity(0.06))

                Section("お知らせ") {
                    Toggle("デイリーチャレンジのお知らせ", isOn: notificationsBinding)
                    Text("毎日19:30に今日のチャレンジを、連続プレイが途切れそうな夜にリマインドを送ります。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.white.opacity(0.06))

                Section("プロフィール") {
                    HStack {
                        Text("ニックネーム")
                        TextField("ニックネーム", text: $settings.nickname)
                            .multilineTextAlignment(.trailing)
                            .submitLabel(.done)
                            .onSubmit { settings.normalizeNickname() }
                    }
                    Text("近くの人と対戦するときに相手の画面に表示されます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.white.opacity(0.06))

                Section("遊び方") {
                    Button("遊び方を見る") { showHowToPlay = true }
                    Button("操作のヒントをもう一度表示する") {
                        UserDefaults.standard.set(false, forKey: "tutorial.completed")
                        UserDefaults.standard.set(false, forKey: "tutorial.reachSeen")
                        showHintsResetNotice = true
                    }
                }
                .listRowBackground(Color.white.opacity(0.06))

                if gameCenter.isAuthenticated {
                    Section("Game Center") {
                        Button("ランキングと実績を見る") { gameCenter.showDashboard() }
                        Text("\(gameCenter.localPlayerName) としてサインイン中")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.white.opacity(0.06))
                }

                Section("データ") {
                    Button("戦績をすべてリセット", role: .destructive) { showResetConfirm = true }
                }
                .listRowBackground(Color.white.opacity(0.06))

                Section("このアプリについて") {
                    LabeledContent("バージョン", value: versionText)
                }
                .listRowBackground(Color.white.opacity(0.06))
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.bgDark)
            .onDisappear { settings.normalizeNickname() }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .confirmationDialog("戦績をすべてリセットしますか？", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("リセットする", role: .destructive) { resetAllData() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("ランク・経験値・実績・連続記録が消え、元に戻せません。")
            }
            .alert("ヒントをリセットしました", isPresented: $showHintsResetNotice) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("次の対戦から、操作のヒントをもう一度表示します。")
            }
            .alert("通知が許可されていません", isPresented: $showNotificationDenied) {
                Button("設定を開く") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("閉じる", role: .cancel) {}
            } message: {
                Text("お知らせを受け取るには、iPhoneの設定アプリでこのアプリの通知を許可してください。")
            }
            .fullScreenCover(isPresented: $showHowToPlay) {
                HowToPlayView(onFinish: {
                    settings.hasSeenTutorial = true
                    showHowToPlay = false
                })
            }
        }
        .preferredColorScheme(.dark)
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { settings.isNotificationsEnabled },
            set: { wantsOn in
                if wantsOn {
                    Task { await enableNotifications() }
                } else {
                    settings.isNotificationsEnabled = false
                    NotificationManager.shared.cancelAll()
                }
            }
        )
    }

    private func enableNotifications() async {
        let status = await NotificationManager.shared.authorizationStatus()
        switch status {
        case .denied:
            showNotificationDenied = true
        case .authorized, .provisional, .ephemeral:
            settings.isNotificationsEnabled = true
            NotificationManager.shared.refreshSchedule(stats: stats, settings: settings)
        default:
            if await NotificationManager.shared.requestPermission() {
                NotificationManager.shared.refreshSchedule(stats: stats, settings: settings)
            }
        }
    }

    private func resetAllData() {
        stats.resetAll()
        AchievementStore.shared.reset()
        GameSessionStore.clear()
        NotificationManager.shared.refreshSchedule(stats: stats, settings: settings)
    }
}
