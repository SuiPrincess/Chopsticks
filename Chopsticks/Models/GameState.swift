import Foundation

enum GamePhase: Equatable, Codable, Sendable {
    case playing
    case gameOver(winnerId: UUID)
    /// ターン上限のサドンデス判定で完全に同点だった場合
    case draw

    // MARK: - Codable
    private enum CodingKeys: String, CodingKey {
        case type, winnerId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .playing:
            try container.encode("playing", forKey: .type)
        case .gameOver(let winnerId):
            try container.encode("gameOver", forKey: .type)
            try container.encode(winnerId, forKey: .winnerId)
        case .draw:
            try container.encode("draw", forKey: .type)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "playing":
            self = .playing
        case "gameOver":
            let winnerId = try container.decode(UUID.self, forKey: .winnerId)
            self = .gameOver(winnerId: winnerId)
        case "draw":
            self = .draw
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown type: \(type)")
        }
    }
}

/// アクション適用の結果。演出（ハプティクス・エフェクト）の判断に使う。
struct ActionResult: Equatable, Sendable {
    var deadHandIds: [UUID] = []
    var poisonTriggered = false
    var bombTriggered = false
}

struct GameState: Equatable, Codable, Sendable {
    var player1: Player
    var player2: Player
    var currentPlayerId: UUID
    var phase: GamePhase
    var config: GameConfig
    var turnCount: Int

    /// このターン数に達したらサドンデス判定（千日手・膠着対策）
    static let turnLimit = 60

    init(config: GameConfig = GameConfig(), player1Starts: Bool = true) {
        let p1Name: String
        let p2Name: String
        switch config.gameMode {
        case .vsAI:
            p1Name = "あなた"
            p2Name = config.aiLevel.map { "CPU Lv.\($0)" } ?? (config.aiDifficulty == .hard ? "CPU つよい" : "CPU かんたん")
        case .online, .nearby:
            p1Name = "あなた"
            p2Name = "対戦相手"
        case .localTwoPlayer:
            p1Name = "プレイヤー1"
            p2Name = "プレイヤー2"
        }
        let p1 = Player(name: p1Name, handCount: config.handCount)
        let p2 = Player(name: p2Name, handCount: config.handCount)
        self.player1 = p1
        self.player2 = p2
        self.currentPlayerId = player1Starts ? p1.id : p2.id
        self.phase = .playing
        self.config = config
        self.turnCount = 0
    }
}

// MARK: - Turn helpers
extension GameState {
    var isPlayer1Turn: Bool { currentPlayerId == player1.id }
    var currentPlayer: Player { isPlayer1Turn ? player1 : player2 }
    var opponentPlayer: Player { isPlayer1Turn ? player2 : player1 }

    mutating func switchTurn() {
        currentPlayerId = isPlayer1Turn ? player2.id : player1.id
        turnCount += 1
    }
}

// MARK: - Rule application
extension GameState {
    /// 現在の手番プレイヤーのアクションを、全ルール（毒・ミラー・爆弾を含む）に
    /// 従って適用する。手番の切り替えは行わない。
    /// 実プレイ（ViewModel）とAIのシミュレーションの両方がここを通ることで、
    /// ルールの実装が常に一致する。
    @discardableResult
    mutating func apply(_ action: GameAction) -> ActionResult {
        var result = ActionResult()
        switch action {
        case .tap(let attackerHandId, let targetHandId):
            applyTap(attackerHandId: attackerHandId, targetHandId: targetHandId, result: &result)
        case .split(let newDistribution):
            applySplit(newDistribution)
        }
        if config.isBombEnabled {
            processBombs(result: &result)
        }
        return result
    }

    private mutating func applyTap(attackerHandId: UUID, targetHandId: UUID, result: inout ActionResult) {
        guard let attackerHand = currentPlayer.hand(for: attackerHandId), attackerHand.isAlive,
              let targetHand = opponentPlayer.hand(for: targetHandId), targetHand.isAlive
        else { return }

        let overflowWraps = config.isOverflowWrapEnabled
        let attackingFingers = attackerHand.fingerCount

        // 毒（相討ち）: 指1本の手で「2本以上の手」を攻撃すると相手の手を即死させるが、毒を使った手も死ぬ。
        // 1本同士の攻撃は通常どおり（全員1本で始まるため、開幕から相討ちしか選べないと後手必勝になる）。
        if Self.isPoisonAttack(config: config, attackingFingers: attackingFingers, targetFingers: targetHand.fingerCount) {
            withOpponentPlayer { player in
                player.updateHand(id: targetHandId) { $0.fingerCount = 0 }
            }
            withCurrentPlayer { player in
                player.updateHand(id: attackerHandId) { $0.fingerCount = 0 }
            }
            result.poisonTriggered = true
            result.deadHandIds.append(attackerHandId)
        } else {
            withOpponentPlayer { player in
                player.updateHand(id: targetHandId) {
                    $0.receiveTap(from: attackingFingers, overflowWraps: overflowWraps)
                }
            }
        }
        if opponentPlayer.hand(for: targetHandId)?.isAlive == false {
            result.deadHandIds.append(targetHandId)
        }

        // ミラー: 攻撃した本数が自分の手にも加算される（毒で既に死んだ手には適用しない）
        if config.isMirrorEnabled && !result.poisonTriggered {
            withCurrentPlayer { player in
                player.updateHand(id: attackerHandId) {
                    $0.receiveTap(from: attackingFingers, overflowWraps: overflowWraps)
                }
            }
            if currentPlayer.hand(for: attackerHandId)?.isAlive == false {
                result.deadHandIds.append(attackerHandId)
            }
        }
    }

    private mutating func applySplit(_ newDistribution: [Int]) {
        guard config.isSplittingEnabled,
              currentPlayer.isValidSplit(
                newDistribution: newDistribution,
                allowRevival: config.isDeadHandRevivalEnabled
              )
        else { return }
        withCurrentPlayer { player in
            for (i, count) in newDistribution.enumerated() {
                player.hands[i].fingerCount = count
            }
        }
    }

    /// 爆弾: ちょうど4本になった手は爆発して死に、他の全ての生きた手に1ダメージ（連鎖あり）。
    /// 常に最新の盤面を見て判定する（古いスナップショットで二重に爆発させない）。
    /// 爆風の1ダメージで5になって死んだ手も`deadHandIds`に含める。
    private mutating func processBombs(result: inout ActionResult) {
        var exploded: Set<UUID> = []
        let overflowWraps = config.isOverflowWrapEnabled

        while let bomb = (player1.hands + player2.hands).first(where: {
            $0.isAlive && $0.fingerCount == 4 && !exploded.contains($0.id)
        }) {
            exploded.insert(bomb.id)
            result.bombTriggered = true
            result.deadHandIds.append(bomb.id)

            let aliveBefore = Set((player1.hands + player2.hands).filter(\.isAlive).map(\.id))

            if let idx = player1.handIndex(for: bomb.id) {
                player1.hands[idx].fingerCount = 0
            } else if let idx = player2.handIndex(for: bomb.id) {
                player2.hands[idx].fingerCount = 0
            }
            for i in player1.hands.indices where player1.hands[i].id != bomb.id {
                player1.hands[i].receiveTap(from: 1, overflowWraps: overflowWraps)
            }
            for i in player2.hands.indices where player2.hands[i].id != bomb.id {
                player2.hands[i].receiveTap(from: 1, overflowWraps: overflowWraps)
            }

            let aliveAfter = Set((player1.hands + player2.hands).filter(\.isAlive).map(\.id))
            for id in aliveBefore.subtracting(aliveAfter) where id != bomb.id {
                result.deadHandIds.append(id)
            }
        }
    }

    static func isPoisonAttack(config: GameConfig, attackingFingers: Int, targetFingers: Int) -> Bool {
        config.isPoisonEnabled && attackingFingers == 1 && targetFingers >= 2
    }

    private mutating func withCurrentPlayer(_ body: (inout Player) -> Void) {
        if isPlayer1Turn { body(&player1) } else { body(&player2) }
    }

    private mutating func withOpponentPlayer(_ body: (inout Player) -> Void) {
        if isPlayer1Turn { body(&player2) } else { body(&player1) }
    }
}

// MARK: - Sudden death / threat analysis
extension GameState {
    enum SuddenDeathOutcome: Equatable {
        case winner(UUID)
        case draw
    }

    /// ターン上限到達時の判定: 生きてる手の数 → 指の合計が少ない方 → 引き分け
    func suddenDeathOutcome() -> SuddenDeathOutcome {
        if player1.aliveHands.count != player2.aliveHands.count {
            return .winner(player1.aliveHands.count > player2.aliveHands.count ? player1.id : player2.id)
        }
        if player1.totalFingers != player2.totalFingers {
            return .winner(player1.totalFingers < player2.totalFingers ? player1.id : player2.id)
        }
        return .draw
    }

    /// その手が、相手のいずれかの手からの1回の攻撃で死にうるか（リーチ表示用）
    func isHandThreatened(_ handId: UUID) -> Bool {
        let (owner, enemy): (Player, Player)
        if player1.hand(for: handId) != nil {
            (owner, enemy) = (player1, player2)
        } else if player2.hand(for: handId) != nil {
            (owner, enemy) = (player2, player1)
        } else {
            return false
        }
        guard let hand = owner.hand(for: handId), hand.isAlive else { return false }
        for attacker in enemy.aliveHands {
            if Self.isPoisonAttack(config: config, attackingFingers: attacker.fingerCount, targetFingers: hand.fingerCount) {
                return true
            }
            var simulated = hand
            simulated.receiveTap(from: attacker.fingerCount, overflowWraps: config.isOverflowWrapEnabled)
            if !simulated.isAlive { return true }
            if config.isBombEnabled && simulated.fingerCount == 4 { return true }
        }
        return false
    }
}
