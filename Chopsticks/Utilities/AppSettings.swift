import Foundation
import Observation

/// ユーザー設定。UserDefaultsに即時保存。
@Observable
@MainActor
final class AppSettings {
    static let shared = AppSettings()

    var isSoundEnabled: Bool { didSet { defaults.set(isSoundEnabled, forKey: Key.sound) } }
    var isHapticsEnabled: Bool { didSet { defaults.set(isHapticsEnabled, forKey: Key.haptics) } }
    /// 画面シェイク・紙吹雪・パルスなどの派手な演出を抑える（システムの「視差効果を減らす」とは独立）
    var reducesEffects: Bool { didSet { defaults.set(reducesEffects, forKey: Key.reduceEffects) } }
    var isNotificationsEnabled: Bool { didSet { defaults.set(isNotificationsEnabled, forKey: Key.notifications) } }
    /// 遊び方チュートリアルを一度見たか（初回起動時に表示する）
    var hasSeenTutorial: Bool { didSet { defaults.set(hasSeenTutorial, forKey: Key.seenTutorial) } }
    /// 通知の許可をすでに尋ねたか（断られたら二度と自動では尋ねない）
    var hasAskedNotificationPermission: Bool { didSet { defaults.set(hasAskedNotificationPermission, forKey: Key.askedNotifications) } }
    /// 起動回数（オンボーディングやレビュー依頼のタイミング判断に使う）
    private(set) var launchCount: Int
    /// 近くの人・オンライン対戦で相手に表示される名前
    var nickname: String { didSet { defaults.set(nickname, forKey: Key.nickname) } }
    /// 最後に「ルール確認」画面で確認したルールの識別子。同じルールなら確認画面を省略する。
    var lastConfirmedRulesKey: String? { didSet { defaults.set(lastConfirmedRulesKey, forKey: Key.lastConfirmedRules) } }

    private let defaults: UserDefaults

    private enum Key {
        static let sound = "settings.sound"
        static let haptics = "settings.haptics"
        static let reduceEffects = "settings.reduceEffects"
        static let notifications = "settings.notifications"
        static let seenTutorial = "settings.hasSeenTutorial"
        static let askedNotifications = "settings.hasAskedNotifications"
        static let launchCount = "settings.launchCount"
        static let nickname = "profile.nickname"
        static let lastConfirmedRules = "settings.lastConfirmedRulesKey"
        static let customRules = "settings.customRules"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isSoundEnabled = defaults.object(forKey: Key.sound) as? Bool ?? true
        isHapticsEnabled = defaults.object(forKey: Key.haptics) as? Bool ?? true
        reducesEffects = defaults.bool(forKey: Key.reduceEffects)
        isNotificationsEnabled = defaults.object(forKey: Key.notifications) as? Bool ?? false
        // 旧バージョンのコーチマーク完了フラグも「見た」扱いにする
        hasSeenTutorial = defaults.bool(forKey: Key.seenTutorial) || defaults.bool(forKey: "tutorial.completed")
        hasAskedNotificationPermission = defaults.bool(forKey: Key.askedNotifications)
        launchCount = defaults.integer(forKey: Key.launchCount)
        if let saved = defaults.string(forKey: Key.nickname), !saved.isEmpty {
            nickname = saved
        } else {
            let generated = "プレイヤー" + String(format: "%04d", Int.random(in: 0...9999))
            nickname = generated
            defaults.set(generated, forKey: Key.nickname)
        }
        lastConfirmedRulesKey = defaults.string(forKey: Key.lastConfirmedRules)
    }

    // MARK: - ルール設定の保存（2人対戦・フリー対戦で使う）

    /// 保存済みのカスタムルール。なければ標準。
    func loadCustomRules() -> GameConfig {
        guard let data = defaults.data(forKey: Key.customRules),
              let config = try? JSONDecoder().decode(GameConfig.self, from: data)
        else { return GameConfig() }
        return config
    }

    func saveCustomRules(_ config: GameConfig) {
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: Key.customRules)
        }
    }

    func registerLaunch() {
        launchCount += 1
        defaults.set(launchCount, forKey: Key.launchCount)
    }
}
