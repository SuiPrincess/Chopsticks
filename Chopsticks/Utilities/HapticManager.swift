import UIKit

@MainActor
enum HapticManager {
    private static var isEnabled: Bool {
        SettingsStore.shared.isHapticsEnabled
    }

    static func handTap() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func handSelect() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func handDeath() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func split() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    static func victory() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func turnSwitch() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func bombExplosion() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func poisonKill() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }
}
