import UserNotifications

/// デイリーリマインダー（ローカル通知）。オプトイン制。
@MainActor
enum NotificationManager {
    private static let reminderID = "chopsticks.daily.reminder"

    /// 通知許可を取り、毎日19:30のリマインダーを登録する。
    /// 許可が得られなかった場合はfalse。
    static func enableDailyReminder() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }

        let content = UNMutableNotificationContent()
        content.title = "今日の割り箸バトル 🥢"
        content.body = "1勝して連続プレイ日数をつなごう！CPUが待ってます"
        content.sound = .default

        var components = DateComponents()
        components.hour = 19
        components.minute = 30
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger)
        try? await center.add(request)
        return true
    }

    static func disableDailyReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [reminderID])
    }
}
