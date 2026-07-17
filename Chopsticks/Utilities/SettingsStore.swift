import Foundation
import Observation

/// アプリ設定（サウンド・ハプティクス・通知）とヒント回数制限。UserDefaultsに永続化。
/// テストから隔離スイート＋任意日付で検証できるよう、defaultsと日付を注入可能。
@Observable
@MainActor
final class SettingsStore {
    static let shared = SettingsStore(defaults: .standard)

    /// 無料ユーザーが1日に使えるヒント回数（プレミアムは無制限）
    static let freeHintsPerDay = 3

    private let defaults: UserDefaults

    var isSoundEnabled: Bool {
        didSet { defaults.set(isSoundEnabled, forKey: Key.sound) }
    }

    var isHapticsEnabled: Bool {
        didSet { defaults.set(isHapticsEnabled, forKey: Key.haptics) }
    }

    var isDailyReminderEnabled: Bool {
        didSet { defaults.set(isDailyReminderEnabled, forKey: Key.reminder) }
    }

    private enum Key {
        static let sound = "settings.soundEnabled"
        static let haptics = "settings.hapticsEnabled"
        static let reminder = "settings.dailyReminderEnabled"
        static let hintDate = "hint.quota.date"
        static let hintCount = "hint.quota.count"
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        isSoundEnabled = (defaults.object(forKey: Key.sound) as? Bool) ?? true
        isHapticsEnabled = (defaults.object(forKey: Key.haptics) as? Bool) ?? true
        isDailyReminderEnabled = defaults.bool(forKey: Key.reminder)
    }

    // MARK: - ヒント回数制限

    var hintsUsedToday: Int {
        hintsUsed(asOf: .now)
    }

    func hintsUsed(asOf date: Date) -> Int {
        guard let last = defaults.object(forKey: Key.hintDate) as? Date,
              Calendar.current.isDate(last, inSameDayAs: date)
        else { return 0 }
        return defaults.integer(forKey: Key.hintCount)
    }

    var hintsRemainingToday: Int {
        max(0, Self.freeHintsPerDay - hintsUsedToday)
    }

    /// ヒントを1回消費する。上限に達していたらfalse。
    func consumeHint(on date: Date = .now) -> Bool {
        let used = hintsUsed(asOf: date)
        guard used < Self.freeHintsPerDay else { return false }
        defaults.set(date, forKey: Key.hintDate)
        defaults.set(used + 1, forKey: Key.hintCount)
        return true
    }
}
