import Foundation

enum GameAction: Equatable, Codable {
    case tap(attackerHandId: UUID, targetHandId: UUID)
    case split(newDistribution: [Int])

    // MARK: - Codable
    private enum CodingKeys: String, CodingKey {
        case type, attackerHandId, targetHandId, newDistribution
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .tap(let attackerHandId, let targetHandId):
            try container.encode("tap", forKey: .type)
            try container.encode(attackerHandId, forKey: .attackerHandId)
            try container.encode(targetHandId, forKey: .targetHandId)
        case .split(let newDistribution):
            try container.encode("split", forKey: .type)
            try container.encode(newDistribution, forKey: .newDistribution)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "tap":
            let attackerHandId = try container.decode(UUID.self, forKey: .attackerHandId)
            let targetHandId = try container.decode(UUID.self, forKey: .targetHandId)
            self = .tap(attackerHandId: attackerHandId, targetHandId: targetHandId)
        case "split":
            let newDistribution = try container.decode([Int].self, forKey: .newDistribution)
            self = .split(newDistribution: newDistribution)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown type: \(type)")
        }
    }
}
