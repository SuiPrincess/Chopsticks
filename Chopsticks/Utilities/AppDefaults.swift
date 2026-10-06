import Foundation

/// アプリのデータの保存先。単体テストの実行中は別の領域を使い、
/// シミュレータや端末に入っている実際の戦績・実績・保存データを消さないようにする。
enum AppDefaults {
    static let store: UserDefaults = {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil,
           let suite = UserDefaults(suiteName: "com.suiprincess.chopsticks.unittests") {
            return suite
        }
        return .standard
    }()
}
