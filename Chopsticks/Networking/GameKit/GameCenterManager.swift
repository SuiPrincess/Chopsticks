import GameKit

@Observable
@MainActor
final class GameCenterManager {
    static let shared = GameCenterManager()

    /// App Store Connectで設定するリーダーボードID（未設定なら送信は静かに失敗する）
    static let rankLeaderboardID = "com.suiprincess.chopsticks.rank"

    /// App Store Connectで設定する実績ID（未設定なら送信は静かに失敗する）
    enum Achievement: String {
        case firstWin = "com.suiprincess.chopsticks.firstwin"
        case streak3 = "com.suiprincess.chopsticks.streak3"
        case streak10 = "com.suiprincess.chopsticks.streak10"
        case perfectWin = "com.suiprincess.chopsticks.perfect"
        case beatOni = "com.suiprincess.chopsticks.oni"
        case rankMax = "com.suiprincess.chopsticks.rankmax"
    }

    private(set) var isAuthenticated = false
    private(set) var localPlayerName = ""
    var authenticationError: String?

    private init() {}

    /// 実績を解除する。未ログイン・実績未設定の場合は何もしない。
    /// 解除済みの実績を再送してもGame Center側で無視される。
    func unlock(_ achievement: Achievement) {
        guard isAuthenticated else { return }
        let report = GKAchievement(identifier: achievement.rawValue)
        report.percentComplete = 100
        report.showsCompletionBanner = true
        GKAchievement.report([report]) { _ in
            // 失敗（未設定等）は無視する
        }
    }

    /// ランク戦のレベルをリーダーボードに送信する。
    /// 未ログイン・リーダーボード未設定の場合は何もしない。
    func submitRankLevel(_ level: Int) {
        guard isAuthenticated else { return }
        GKLeaderboard.submitScore(
            level,
            context: 0,
            player: GKLocalPlayer.local,
            leaderboardIDs: [Self.rankLeaderboardID]
        ) { _ in
            // 失敗（未設定等）は無視する
        }
    }

    func authenticateLocalPlayer() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.authenticationError = error.localizedDescription
                    self.isAuthenticated = false
                    return
                }
                // viewController != nil means the system wants to show a login UI
                // In SwiftUI this is handled automatically by Game Center
                if viewController == nil {
                    self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                    self.localPlayerName = GKLocalPlayer.local.displayName
                }
            }
        }
    }
}
