import Foundation

struct Player: Identifiable, Equatable {
    let id: UUID
    let name: String
    var hands: [Hand]

    var isDefeated: Bool { hands.allSatisfy { !$0.isAlive } }
    var totalFingers: Int { hands.reduce(0) { $0 + $1.fingerCount } }
    var aliveHands: [Hand] { hands.filter { $0.isAlive } }

    func hand(for id: UUID) -> Hand? {
        hands.first { $0.id == id }
    }

    func handIndex(for id: UUID) -> Int? {
        hands.firstIndex { $0.id == id }
    }

    mutating func updateHand(id: UUID, _ transform: (inout Hand) -> Void) {
        guard let index = hands.firstIndex(where: { $0.id == id }) else { return }
        transform(&hands[index])
    }

    func isValidSplit(newDistribution: [Int], allowRevival: Bool) -> Bool {
        let total = totalFingers
        guard newDistribution.count == hands.count else { return false }
        guard newDistribution.reduce(0, +) == total else { return false }
        guard newDistribution.allSatisfy({ $0 >= 0 && $0 <= 4 }) else { return false }
        let current = hands.map(\.fingerCount)
        guard newDistribution != current else { return false }
        // 2手の場合、左右入れ替えは同じ状態なので不可
        if hands.count == 2 {
            guard newDistribution.sorted() != current.sorted() else { return false }
        }
        if !allowRevival {
            for (i, hand) in hands.enumerated() {
                if !hand.isAlive && newDistribution[i] > 0 { return false }
            }
        }
        return true
    }

    init(id: UUID = UUID(), name: String, handCount: Int = 2) {
        self.id = id
        self.name = name
        self.hands = (0..<handCount).map { _ in Hand() }
    }
}
