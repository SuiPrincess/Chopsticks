import Foundation
import UIKit
import UserNotifications

/// ローカル通知による「戻ってくるきっかけ」。
/// - 翌日以降7日分の「今日のチャレンジ」リマインド（各日の内容は日付から計算できるので具体的に書ける）
/// - 連続プレイ日数が途切れそうな日の夜に1回だけ警告
/// 許可は勝利直後など気分の良い瞬間にだけ、一度だけ尋ねる。
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private static let dailyPrefix = "daily."
    private static let streakId = "streak.atRisk"
    private static let reminderHour = 19
    private static let reminderMinute = 30
    private static let streakHour = 20
    private static let streakMinute = 45

    /// 直近の予約処理。新しい呼び出しは前の処理を取り消し、終わるのを待ってから実行する。
    private var refreshTask: Task<Void, Never>?

    private init() {}

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// 許可ダイアログを表示。許可されたらtrue。
    @discardableResult
    func requestPermission() async -> Bool {
        AppSettings.shared.hasAskedNotificationPermission = true
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        AppSettings.shared.isNotificationsEnabled = granted
        return granted
    }

    /// 「許可を尋ねる価値がある瞬間」か: 2勝以上していて、まだ尋ねたことがない
    func shouldOfferPermission(stats: GameStats) -> Bool {
        !AppSettings.shared.hasAskedNotificationPermission && stats.wins >= 2
    }

    /// 現在の戦績と設定に合わせて予定を組み直す（起動時・バックグラウンド移行時・設定変更時に呼ぶ）。
    /// 何度呼んでも、組み直しは1つずつ順番に行われる（途中の古い処理が新しい予定を壊さない）。
    func refreshSchedule(stats: GameStats, settings: AppSettings, calendar: Calendar = .current, now: Date = Date()) {
        let previous = refreshTask
        previous?.cancel()
        // バックグラウンドへ移る直前でも、予約を最後まで終えられるようにする
        let background = UIApplication.shared.beginBackgroundTask(withName: "refreshNotifications")
        refreshTask = Task { @MainActor in
            defer { UIApplication.shared.endBackgroundTask(background) }
            await previous?.value
            guard !Task.isCancelled else { return }

            center.removeAllPendingNotificationRequests()
            guard settings.isNotificationsEnabled else { return }
            let status = await authorizationStatus()
            guard status == .authorized || status == .provisional else { return }
            guard !Task.isCancelled else { return }

            var requests: [UNNotificationRequest] = []

            // 翌日から7日分のデイリーチャレンジ
            for offset in 1...7 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
                var components = calendar.dateComponents([.year, .month, .day], from: day)
                components.hour = Self.reminderHour
                components.minute = Self.reminderMinute
                let challenge = DailyChallenge.forDate(day, calendar: calendar)
                let content = UNMutableNotificationContent()
                content.title = "今日のチャレンジ「\(challenge.title)」"
                content.body = "CPU Lv.\(challenge.cpuLevel)に勝つと+\(DailyChallenge.bonusXP)XP。1日1回だけのボーナス！"
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                requests.append(UNNotificationRequest(identifier: Self.dailyPrefix + challenge.dayKey, content: content, trigger: trigger))
            }

            // 連続記録が途切れそうな日（最後に遊んだ翌日）の夜
            if stats.dailyStreak >= 2, let last = stats.lastPlayDay,
               let riskDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: last)) {
                var components = calendar.dateComponents([.year, .month, .day], from: riskDay)
                components.hour = Self.streakHour
                components.minute = Self.streakMinute
                if let fireDate = calendar.date(from: components), fireDate > now {
                    let content = UNMutableNotificationContent()
                    content.title = "🔥 \(stats.dailyStreak)日連続の記録が途切れそう"
                    content.body = "1戦だけでも遊べば記録が続きます。CPUにサクッと1勝しよう！"
                    content.sound = .default
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    requests.append(UNNotificationRequest(identifier: Self.streakId, content: content, trigger: trigger))
                }
            }

            for request in requests {
                guard !Task.isCancelled else { return }
                try? await center.add(request)
            }
        }
    }

    /// 予約済みの通知をすべて消す（設定でOFFにしたとき）。進行中の予約処理も止める。
    func cancelAll() {
        refreshTask?.cancel()
        refreshTask = nil
        center.removeAllPendingNotificationRequests()
    }
}
