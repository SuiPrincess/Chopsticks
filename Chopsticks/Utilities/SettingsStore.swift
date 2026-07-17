import Foundation
import Observation

/// アプリ設定（サウンド・ハプティクス）。UserDefaultsに永続化。
@Observable
@MainActor
final class SettingsStore {
    static let shared = SettingsStore()

    var isSoundEnabled: Bool {
        didSet { UserDefaults.standard.set(isSoundEnabled, forKey: Key.sound) }
    }

    var isHapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(isHapticsEnabled, forKey: Key.haptics) }
    }

    private enum Key {
        static let sound = "settings.soundEnabled"
        static let haptics = "settings.hapticsEnabled"
    }

    private init() {
        let defaults = UserDefaults.standard
        isSoundEnabled = (defaults.object(forKey: Key.sound) as? Bool) ?? true
        isHapticsEnabled = (defaults.object(forKey: Key.haptics) as? Bool) ?? true
    }
}
