import SwiftUI

enum Anim {
    static let finger: Animation = .spring(response: 0.35, dampingFraction: 0.65)
    static let turnSwitch: Animation = .easeInOut(duration: 0.4)
    static let handDeath: Animation = .easeOut(duration: 0.6)
    static let splitPanel: Animation = .spring(response: 0.4, dampingFraction: 0.8)
    static let gameOver: Animation = .spring(response: 0.6, dampingFraction: 0.7)
    static let glowPulse: Animation = .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
    static let buttonPress: Animation = .spring(response: 0.2)
}
