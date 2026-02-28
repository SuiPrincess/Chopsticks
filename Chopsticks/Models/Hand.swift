import Foundation

struct Hand: Identifiable, Equatable {
    let id: UUID
    var fingerCount: Int

    var isAlive: Bool { fingerCount > 0 }

    /// ちょうど5で死亡、5超えはループ（result - 5）
    mutating func receiveTap(from attackingFingers: Int, overflowWraps: Bool) {
        guard isAlive else { return }
        fingerCount += attackingFingers
        if overflowWraps {
            if fingerCount == 5 {
                fingerCount = 0
            } else if fingerCount > 5 {
                fingerCount -= 5
            }
        } else {
            // クラシックルール: 5以上で死亡
            if fingerCount >= 5 {
                fingerCount = 0
            }
        }
    }

    init(id: UUID = UUID(), fingerCount: Int = 1) {
        self.id = id
        self.fingerCount = fingerCount
    }
}
