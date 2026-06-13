import Foundation

enum MultiplayerMessage: Codable {
    case configProposal(GameConfig)
    case configAccepted
    case gameStart(GameState)
    case action(GameAction)
    case stateSync(GameState)
    case rematchRequest
    case rematchAccepted
    case disconnect

    // MARK: - Codable
    private enum CodingKeys: String, CodingKey {
        case type, config, state, action
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .configProposal(let config):
            try container.encode("configProposal", forKey: .type)
            try container.encode(config, forKey: .config)
        case .configAccepted:
            try container.encode("configAccepted", forKey: .type)
        case .gameStart(let state):
            try container.encode("gameStart", forKey: .type)
            try container.encode(state, forKey: .state)
        case .action(let action):
            try container.encode("action", forKey: .type)
            try container.encode(action, forKey: .action)
        case .stateSync(let state):
            try container.encode("stateSync", forKey: .type)
            try container.encode(state, forKey: .state)
        case .rematchRequest:
            try container.encode("rematchRequest", forKey: .type)
        case .rematchAccepted:
            try container.encode("rematchAccepted", forKey: .type)
        case .disconnect:
            try container.encode("disconnect", forKey: .type)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "configProposal":
            self = .configProposal(try container.decode(GameConfig.self, forKey: .config))
        case "configAccepted":
            self = .configAccepted
        case "gameStart":
            self = .gameStart(try container.decode(GameState.self, forKey: .state))
        case "action":
            self = .action(try container.decode(GameAction.self, forKey: .action))
        case "stateSync":
            self = .stateSync(try container.decode(GameState.self, forKey: .state))
        case "rematchRequest":
            self = .rematchRequest
        case "rematchAccepted":
            self = .rematchAccepted
        case "disconnect":
            self = .disconnect
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown type: \(type)")
        }
    }

    // MARK: - Serialization helpers
    func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func decoded(from data: Data) -> MultiplayerMessage? {
        try? JSONDecoder().decode(MultiplayerMessage.self, from: data)
    }
}
