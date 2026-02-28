import Foundation

enum GamePhase: Equatable {
    case playing
    case gameOver(winnerId: UUID)
}

struct GameState: Equatable {
    var player1: Player
    var player2: Player
    var currentPlayerId: UUID
    var phase: GamePhase
    var config: GameConfig
    var turnCount: Int

    init(config: GameConfig = GameConfig()) {
        let p1 = Player(name: "Player 1", handCount: config.handCount)
        let p2Name = config.gameMode == .vsAI ? "CPU" : "Player 2"
        let p2 = Player(name: p2Name, handCount: config.handCount)
        self.player1 = p1
        self.player2 = p2
        self.currentPlayerId = p1.id
        self.phase = .playing
        self.config = config
        self.turnCount = 0
    }
}
