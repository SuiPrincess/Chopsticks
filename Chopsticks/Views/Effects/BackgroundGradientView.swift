import SwiftUI

/// ゆっくり動く背景グラデーション。
/// 毎フレーム全画面を再描画し続けないよう、20fpsに抑え、バックグラウンド・視差効果オフ時は止める。
struct BackgroundGradientView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let paused = reduceMotion || AppSettings.shared.reducesEffects || scenePhase != .active
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: paused)) { context in
            let t: Double = paused ? 0.5 : (sin(context.date.timeIntervalSinceReferenceDate / 6.0 * .pi) + 1) / 2
            ZStack {
                LinearGradient(
                    colors: [
                        AppTheme.bgDark,
                        AppTheme.bgDeep,
                        AppTheme.bgMid,
                        AppTheme.bgDeep,
                        AppTheme.bgDark,
                    ],
                    startPoint: UnitPoint(x: 0, y: 1 - t),
                    endPoint: UnitPoint(x: 1, y: t)
                )

                RadialGradient(
                    colors: [AppTheme.accent.opacity(0.06), .clear],
                    center: UnitPoint(x: 0.4 + 0.2 * t, y: 0.7 - 0.4 * t),
                    startRadius: 50,
                    endRadius: 400
                )
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
