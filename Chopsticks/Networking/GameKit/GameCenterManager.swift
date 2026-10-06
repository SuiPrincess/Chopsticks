import GameKit
import UIKit

/// Game Center認証・実績・リーダーボード。
/// 実績IDは`Achievement.rawValue`、リーダーボードIDは`Leaderboard`と同じ文字列をApp Store Connectに登録する。
@Observable
@MainActor
final class GameCenterManager {
    static let shared = GameCenterManager()

    enum Leaderboard: String, CaseIterable {
        case bestStreak = "best_streak"
        case rankLevel = "rank_level"
        case playerXP = "player_xp"
        case maxLevelWins = "max_level_wins"
    }

    private(set) var isAuthenticated = false
    /// 認証の結果（成功・失敗）が一度でも返ってきたか。falseの間は「サインイン処理中／未開始」。
    private(set) var didFinishAuthentication = false
    private(set) var localPlayerName = ""
    var authenticationError: String?
    private var didStartAuthentication = false

    private init() {}

    /// 認証を開始する。今回初めて開始したらtrue（システムのサインインUIが出る可能性がある）。
    @discardableResult
    func authenticateLocalPlayer() -> Bool {
        guard !didStartAuthentication else { return false }
        didStartAuthentication = true
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                guard let self else { return }
                if let viewController {
                    // ログインUIが必要な場合はシステムのVCを表示する（表示しないと永久に未ログインのまま）
                    Self.topViewController()?.present(viewController, animated: true)
                    return
                }
                if let error {
                    self.authenticationError = error.localizedDescription
                    self.isAuthenticated = false
                    self.didFinishAuthentication = true
                    return
                }
                self.didFinishAuthentication = true
                self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                self.localPlayerName = GKLocalPlayer.local.displayName
                self.authenticationError = nil
                if self.isAuthenticated {
                    GKAccessPoint.shared.isActive = false
                }
            }
        }
        return true
    }

    /// Game Centerのダッシュボード（実績・ランキング）を開く
    func showDashboard() {
        guard isAuthenticated else { return }
        GKAccessPoint.shared.trigger(state: .dashboard) {}
    }

    func report(achievements: [Achievement]) {
        guard isAuthenticated, !achievements.isEmpty else { return }
        let reports = achievements.map { achievement -> GKAchievement in
            let a = GKAchievement(identifier: achievement.rawValue)
            a.percentComplete = 100
            a.showsCompletionBanner = false  // アプリ内トーストで見せるため二重に出さない
            return a
        }
        GKAchievement.report(reports) { _ in }
    }

    func submitScores(stats: GameStats) {
        guard isAuthenticated else { return }
        let entries: [(Leaderboard, Int)] = [
            (.bestStreak, stats.bestStreak),
            (.rankLevel, stats.rankLevel),
            (.playerXP, stats.xp),
            (.maxLevelWins, stats.maxLevelWins),
        ]
        for (board, value) in entries where value > 0 {
            GKLeaderboard.submitScore(value, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [board.rawValue]) { _ in }
        }
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
