import Foundation

/// ゲーム全体で共有するルール定数
enum GameRules {
    /// このターン数に達したらサドンデス判定（千日手・膠着対策）
    static let turnLimit = 60
}

/// 1ゲームの記録（初期盤面＋全アクション）。リザルトのリプレイ再生に使う。
struct Replay: Codable, Equatable {
    var initialState: GameState
    var actions: [GameAction]
    var savedAt: Date
}

/// リプレイの盤面列を再構築する。ターン進行（ダブルタップ継続・決着・
/// サドンデス）はGameViewModelの進行と同一のルールで再現する。
enum ReplaySimulator {

    /// 初期盤面を含む、各アクション適用後の盤面列を返す。
    /// 決着した時点で列は終わる（以降のアクションは無視）。
    static func snapshots(for replay: Replay) -> [GameState] {
        var states = [replay.initialState]
        var state = replay.initialState
        var attacksThisTurn = 0

        for action in replay.actions {
            var wasTap = false
            if case .tap = action { wasTap = true }
            state.apply(action)

            let p1Dead = state.player1.isDefeated
            let p2Dead = state.player2.isDefeated
            if p1Dead || p2Dead {
                // 相打ちはとどめを刺した手番側の勝ち（手番は切り替えない）
                let winnerId: UUID
                if p1Dead && p2Dead {
                    winnerId = state.currentPlayerId
                } else if p1Dead {
                    winnerId = state.player2.id
                } else {
                    winnerId = state.player1.id
                }
                state.phase = .gameOver(winnerId: winnerId)
                states.append(state)
                break
            }

            if wasTap && state.config.isDoubleTapEnabled && attacksThisTurn == 0 {
                attacksThisTurn = 1
            } else {
                attacksThisTurn = 0
                state.switchTurn()
                if state.turnCount >= GameRules.turnLimit {
                    resolveSuddenDeath(&state)
                    states.append(state)
                    break
                }
            }
            states.append(state)
        }
        return states
    }

    /// ターン上限到達時の判定: 生きてる手の数 → 指の合計が少ない方 → 引き分け
    private static func resolveSuddenDeath(_ state: inout GameState) {
        let p1 = state.player1
        let p2 = state.player2
        if p1.aliveHands.count != p2.aliveHands.count {
            state.phase = .gameOver(
                winnerId: p1.aliveHands.count > p2.aliveHands.count ? p1.id : p2.id
            )
        } else if p1.totalFingers != p2.totalFingers {
            state.phase = .gameOver(
                winnerId: p1.totalFingers < p2.totalFingers ? p1.id : p2.id
            )
        } else {
            state.phase = .draw
        }
    }
}
