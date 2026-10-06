import Foundation
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

    /// 現在の戦績と設定に合わせて予定を組み直す（アプリがバックグラウンドに入るたびに呼ぶ）
    func refreshSchedule(stats: GameStats, settings: AppSettings, calendar: Calendar = .current, now: Date = Date()) {
        Task {
            await center.removeAllPendingNotificationRequests()
            guard settings.isNotificationsEnabled else { return }
            let status = await authorizationStatus()
            guard status == .authorized || status == .provisional else { return }

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
                try? await center.add(request)
            }
        }
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
