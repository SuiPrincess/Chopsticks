import Foundation

struct Player: Identifiable, Equatable, Codable, Sendable {
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

    /// 分割の妥当性。
    /// - 合計は変わらない、各手は0〜4本
    /// - 生きている手を0本にはできない（分割で自分の手を殺せない）
    /// - 死んだ手に指を配れるのは復活ルールがONのときだけ
    /// - 並べ替えただけの分割は盤面が実質変わらない（＝パス）ため不可
    func isValidSplit(newDistribution: [Int], allowRevival: Bool) -> Bool {
        guard newDistribution.count == hands.count else { return false }
        guard newDistribution.reduce(0, +) == totalFingers else { return false }
        guard newDistribution.allSatisfy({ $0 >= 0 && $0 <= 4 }) else { return false }
        let current = hands.map(\.fingerCount)
        guard newDistribution.sorted() != current.sorted() else { return false }
        for (i, hand) in hands.enumerated() {
            if hand.isAlive && newDistribution[i] == 0 { return false }
            if !hand.isAlive && newDistribution[i] > 0 && !allowRevival { return false }
        }
        return true
    }

    /// 現在の盤面で有効な分割が1つでも存在するか（分割ボタンの表示判定）
    func hasValidSplit(allowRevival: Bool) -> Bool {
        !validSplits(allowRevival: allowRevival).isEmpty
    }

    /// 有効な分割の全列挙
    func validSplits(allowRevival: Bool) -> [[Int]] {
        Self.distributions(total: totalFingers, handCount: hands.count)
            .filter { isValidSplit(newDistribution: $0, allowRevival: allowRevival) }
    }

    /// total本の指をhandCount個の手へ0〜4本ずつ配る全パターン（結果はキャッシュ）
    static func distributions(total: Int, handCount: Int) -> [[Int]] {
        guard handCount > 0 else { return total == 0 ? [[]] : [] }
        guard total <= handCount * 4 else { return [] }
        var results: [[Int]] = []
        for count in 0...min(total, 4) {
            for rest in distributions(total: total - count, handCount: handCount - 1) {
                results.append([count] + rest)
            }
        }
        return results
    }

    init(id: UUID = UUID(), name: String, handCount: Int = 2) {
        self.id = id
        self.name = name
        self.hands = (0..<handCount).map { _ in Hand() }
    }
}
