import SwiftUI

@main
struct ChopsticksApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}

/// アプリ全体の土台。起動時の準備・実績トースト・バックグラウンド移行時の通知予約を担当する。
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var didSetup = false

    var body: some View {
        MenuView()
            .overlay(alignment: .top) {
                AchievementToastHost()
            }
            .task {
                guard !didSetup else { return }
                didSetup = true
                AppSettings.shared.registerLaunch()
                SoundManager.shared.prepare(isEnabled: { AppSettings.shared.isSoundEnabled })
                // 初回起動でいきなりGame Centerのサインイン画面を出さない。
                // 遊んだことのある人は静かにサインインし、実績やランキングを送れるようにする。
                if GameStats.shared.hasPlayed {
                    GameCenterManager.shared.authenticateLocalPlayer()
                }
                NotificationManager.shared.refreshSchedule(stats: GameStats.shared, settings: AppSettings.shared)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    NotificationManager.shared.refreshSchedule(stats: GameStats.shared, settings: AppSettings.shared)
                }
            }
    }
}
