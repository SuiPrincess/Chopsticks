import UIKit

@MainActor
enum HapticManager {
    static func handTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func handSelect() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func handDeath() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func split() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    static func victory() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func turnSwitch() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func bombExplosion() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func poisonKill() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }
}
