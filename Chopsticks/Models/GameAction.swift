import Foundation

enum GameAction: Equatable {
    case tap(attackerHandId: UUID, targetHandId: UUID)
    case split(newDistribution: [Int])
}
