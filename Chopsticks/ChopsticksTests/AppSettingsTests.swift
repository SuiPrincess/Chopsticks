import XCTest
@testable import Chopsticks

@MainActor
final class AppSettingsTests: XCTestCase {

    private func makeDefaults() -> (UserDefaults, String) {
        let suite = "AppSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (defaults, suite)
    }

    func testSettingsPersistAcrossInstances() async {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = AppSettings(defaults: defaults)
        XCTAssertTrue(first.isSoundEnabled, "初期値は効果音ON")
        XCTAssertTrue(first.isHapticsEnabled)
        XCTAssertFalse(first.reducesEffects)
        XCTAssertFalse(first.isNotificationsEnabled, "通知は許可を得るまでOFF")
        XCTAssertFalse(first.nickname.isEmpty, "ニックネームは自動で付く")

        first.isSoundEnabled = false
        first.isHapticsEnabled = false
        first.reducesEffects = true
        first.hasSeenTutorial = true
        first.nickname = "テスト"
        var rules = GameConfig()
        rules.isBombEnabled = true
        rules.handCount = 3
        first.saveCustomRules(rules)

        let second = AppSettings(defaults: defaults)
        XCTAssertFalse(second.isSoundEnabled)
        XCTAssertFalse(second.isHapticsEnabled)
        XCTAssertTrue(second.reducesEffects)
        XCTAssertTrue(second.hasSeenTutorial)
        XCTAssertEqual(second.nickname, "テスト")
        XCTAssertEqual(second.loadCustomRules(), rules)
    }

    func testNicknameStaysStableOnceGenerated() async {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = AppSettings(defaults: defaults).nickname
        let second = AppSettings(defaults: defaults).nickname
        XCTAssertEqual(first, second)
    }

    func testNormalizeNickname() async {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)

        settings.nickname = "  さくら  "
        settings.normalizeNickname()
        XCTAssertEqual(settings.nickname, "さくら")

        settings.nickname = "あいうえおかきくけこさしすせそ"
        settings.normalizeNickname()
        XCTAssertEqual(settings.nickname.count, 12)

        settings.nickname = "   "
        settings.normalizeNickname()
        XCTAssertTrue(settings.nickname.hasPrefix("プレイヤー"), "空白だけなら自動の名前に戻す")
    }

    func testLegacyTutorialFlagCountsAsSeen() async {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "tutorial.completed")
        XCTAssertTrue(AppSettings(defaults: defaults).hasSeenTutorial, "旧バージョンのコーチマーク完了は遊び方も見た扱い")
    }

    func testLaunchCountIncrements() async {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        settings.registerLaunch()
        settings.registerLaunch()
        XCTAssertEqual(AppSettings(defaults: defaults).launchCount, 2)
    }

    func testBrokenCustomRulesFallBackToStandard() async {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("not json".utf8), forKey: "settings.customRules")
        XCTAssertEqual(AppSettings(defaults: defaults).loadCustomRules(), GameConfig())
    }
}
