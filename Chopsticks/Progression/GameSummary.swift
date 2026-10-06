import Foundation

/// 1ゲームの結果。戦績・XP・実績の判定に使う（UI非依存）。
struct GameSummary: Equatable {
    enum Outcome: Equatable {
        /// ローカルプレイヤー（Player 1 / 自分）が勝った
        case win
        case loss
        case draw
        /// 1台2人対戦など「自分」が特定できない対戦の完了
        case completed
    }

    var mode: GameMode
    var outcome: Outcome
    var turnCount: Int
    var config: GameConfig
    /// 勝者が一本も手を失わなかった
    var isPerfect: Bool = false
    /// 自分の生存手が1本だけの状態を経験してから勝った
    var isComeback: Bool = false
    /// ターン上限のサドンデス判定で決着した
    var decidedBySuddenDeath: Bool = false

    var isWin: Bool { outcome == .win }
}
