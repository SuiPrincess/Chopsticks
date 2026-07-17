import Foundation
import Observation

/// アプリ設定（サウンド・ハプティクス・通知）とヒント回数制限。UserDefaultsに永続化。
@Observable
@MainActor
final class SettingsStore {
    static let shared = SettingsStore()

    /// 無料ユーザーが1日に使えるヒント回数（プレミアムは無制限）
    static let freeHintsPerDay = 3

    var isSoundEnabled: Bool {
        didSet { UserDefaults.standard.set(isSoundEnabled, forKey: Key.sound) }
    }

    var isHapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(isHapticsEnabled, forKey: Key.haptics) }
    }

    var isDailyReminderEnabled: Bool {
        didSet { UserDefaults.standard.set(isDailyReminderEnabled, forKey: Key.reminder) }
    }

    private enum Key {
        static let sound = "settings.soundEnabled"
        static let haptics = "settings.hapticsEnabled"
        static let reminder = "settings.dailyReminderEnabled"
        static let hintDate = "hint.quota.date"
        static let hintCount = "hint.quota.count"
    }

    private init() {
        let defaults = UserDefaults.standard
        isSoundEnabled = (defaults.object(forKey: Key.sound) as? Bool) ?? true
        isHapticsEnabled = (defaults.object(forKey: Key.haptics) as? Bool) ?? true
        isDailyReminderEnabled = defaults.bool(forKey: Key.reminder)
    }

    // MARK: - ヒント回数制限

    var hintsUsedToday: Int {
        let defaults = UserDefaults.standard
        guard let last = defaults.object(forKey: Key.hintDate) as? Date,
              Calendar.current.isDate(last, inSameDayAs: .now)
        else { return 0 }
        return defaults.integer(forKey: Key.hintCount)
    }

    var hintsRemainingToday: Int {
        max(0, Self.freeHintsPerDay - hintsUsedToday)
    }

    /// ヒントを1回消費する。上限に達していたらfalse。
    func consumeHint() -> Bool {
        let used = hintsUsedToday
        guard used < Self.freeHintsPerDay else { return false }
        let defaults = UserDefaults.standard
        defaults.set(Date.now, forKey: Key.hintDate)
        defaults.set(used + 1, forKey: Key.hintCount)
        return true
    }
}
