import Foundation
import Observation

/// 実績。IDはGame Centerの実績IDとしてもそのまま使う（App Store Connectで同じIDを登録する）。
enum Achievement: String, CaseIterable, Identifiable, Codable {
    case firstWin = "first_win"
    case streak3 = "streak_3"
    case streak5 = "streak_5"
    case streak10 = "streak_10"
    case rank5 = "rank_5"
    case rank10 = "rank_10"
    case maxWins10 = "max_wins_10"
    case perfectWin = "perfect_win"
    case speedWin = "speed_win"
    case comeback = "comeback"
    case survivor = "survivor"
    case rulePoison = "rule_poison"
    case ruleBomb = "rule_bomb"
    case ruleMirror = "rule_mirror"
    case ruleDouble = "rule_double"
    case ruleSplit = "rule_split"
    case ruleThreeHands = "rule_three"
    case localDuel = "local_duel"
    case multiplayerWin = "multiplayer_win"
    case daily1 = "daily_1"
    case daily7 = "daily_7"
    case days3 = "days_3"
    case days7 = "days_7"
    case days30 = "days_30"
    case games10 = "games_10"
    case games100 = "games_100"
    case level10 = "level_10"
    case level20 = "level_20"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstWin: "初勝利"
        case .streak3: "3連勝"
        case .streak5: "5連勝"
        case .streak10: "10連勝"
        case .rank5: "ランクLv.5到達"
        case .rank10: "ランクLv.MAX到達"
        case .maxWins10: "頂上の常連"
        case .perfectWin: "無傷の勝利"
        case .speedWin: "電光石火"
        case .comeback: "大逆転"
        case .survivor: "持久戦の覇者"
        case .rulePoison: "毒使い"
        case .ruleBomb: "爆弾魔"
        case .ruleMirror: "鏡の達人"
        case .ruleDouble: "連撃の使い手"
        case .ruleSplit: "分割の妙"
        case .ruleThreeHands: "三本の腕"
        case .localDuel: "差し向かい"
        case .multiplayerWin: "遠くの好敵手"
        case .daily1: "今日の一戦"
        case .daily7: "一週間皆勤"
        case .days3: "3日連続"
        case .days7: "1週間連続"
        case .days30: "1ヶ月連続"
        case .games10: "10戦の経験"
        case .games100: "百戦錬磨"
        case .level10: "プレイヤーLv.10"
        case .level20: "プレイヤーLv.20"
        }
    }

    var detail: String {
        switch self {
        case .firstWin: "CPUに初めて勝つ"
        case .streak3: "CPU戦で3連勝する"
        case .streak5: "CPU戦で5連勝する"
        case .streak10: "CPU戦で10連勝する"
        case .rank5: "ランク戦でLv.5に到達する"
        case .rank10: "ランク戦でLv.10（MAX）に到達する"
        case .maxWins10: "Lv.MAXのCPUに10回勝つ"
        case .perfectWin: "一本も手を失わずに勝つ"
        case .speedWin: "10ターン以内に勝つ"
        case .comeback: "生き残りが片手だけの状態から勝つ"
        case .survivor: "ターン上限の判定で勝つ"
        case .rulePoison: "毒ルールで勝つ"
        case .ruleBomb: "爆弾ルールで勝つ"
        case .ruleMirror: "ミラールールで勝つ"
        case .ruleDouble: "ダブルタップルールで勝つ"
        case .ruleSplit: "分割ルールで勝つ"
        case .ruleThreeHands: "3本手ルールで勝つ"
        case .localDuel: "1台で2人対戦を遊ぶ"
        case .multiplayerWin: "近くの人かオンラインで勝つ"
        case .daily1: "デイリーチャレンジをクリアする"
        case .daily7: "デイリーチャレンジを7回クリアする"
        case .days3: "3日連続で遊ぶ"
        case .days7: "7日連続で遊ぶ"
        case .days30: "30日連続で遊ぶ"
        case .games10: "通算10戦遊ぶ"
        case .games100: "通算100戦遊ぶ"
        case .level10: "プレイヤーレベル10になる"
        case .level20: "プレイヤーレベル20になる"
        }
    }

    var symbol: String {
        switch self {
        case .firstWin: "star.fill"
        case .streak3, .streak5, .streak10: "flame.fill"
        case .rank5, .rank10: "trophy.fill"
        case .maxWins10: "crown.fill"
        case .perfectWin: "shield.checkered"
        case .speedWin: "bolt.fill"
        case .comeback: "arrow.uturn.up"
        case .survivor: "hourglass"
        case .rulePoison: "drop.fill"
        case .ruleBomb: "flame.circle.fill"
        case .ruleMirror: "arrow.uturn.backward"
        case .ruleDouble: "hand.tap.fill"
        case .ruleSplit: "arrow.left.arrow.right"
        case .ruleThreeHands: "hand.raised.fingers.spread"
        case .localDuel: "person.2.fill"
        case .multiplayerWin: "globe"
        case .daily1, .daily7: "calendar.badge.checkmark"
        case .days3, .days7, .days30: "calendar"
        case .games10, .games100: "gamecontroller.fill"
        case .level10, .level20: "sparkles"
        }
    }

    /// 達成前は内容を隠す（ネタバレ防止）
    var isSecret: Bool {
        switch self {
        case .comeback, .survivor, .speedWin: true
        default: false
        }
    }

    /// 実績解除で得られるXP
    var xpReward: Int {
        switch self {
        case .firstWin, .localDuel, .daily1, .games10: 20
        case .streak10, .rank10, .maxWins10, .days30, .games100, .level20, .daily7: 100
        default: 40
        }
    }
}

/// 解除済み実績の永続化と判定。
@Observable
@MainActor
final class AchievementStore {
    static let shared = AchievementStore()

    private(set) var unlocked: [Achievement: Date] = [:]
    /// 直近に解除された実績（トースト表示用）。表示側が消費する。
    var pendingToasts: [Achievement] = []

    private let defaults: UserDefaults
    private let now: () -> Date
    private static let key = "achievements.unlocked"

    init(defaults: UserDefaults = AppDefaults.store, now: @escaping () -> Date = { Date() }) {
        self.defaults = defaults
        self.now = now
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([String: Date].self, from: data) {
            var map: [Achievement: Date] = [:]
            for (raw, date) in decoded {
                if let a = Achievement(rawValue: raw) { map[a] = date }
            }
            unlocked = map
        }
    }

    func isUnlocked(_ achievement: Achievement) -> Bool {
        unlocked[achievement] != nil
    }

    var unlockedCount: Int { unlocked.count }
    var totalCount: Int { Achievement.allCases.count }

    /// ゲーム結果と最新の戦績から新規解除を判定し、解除した実績を返す。
    @discardableResult
    func evaluate(summary: GameSummary?, stats: GameStats) -> [Achievement] {
        var newly: [Achievement] = []
        func check(_ a: Achievement, _ condition: @autoclosure () -> Bool) {
            if unlocked[a] == nil, condition() { newly.append(a) }
        }

        if let s = summary {
            let cpuWin = s.mode == .vsAI && s.isWin
            check(.firstWin, cpuWin)
            check(.perfectWin, s.isWin && s.isPerfect)
            check(.speedWin, s.isWin && s.turnCount <= 10)
            check(.comeback, s.isWin && s.isComeback)
            check(.survivor, s.isWin && s.decidedBySuddenDeath)
            check(.rulePoison, s.isWin && s.config.isPoisonEnabled)
            check(.ruleBomb, s.isWin && s.config.isBombEnabled)
            check(.ruleMirror, s.isWin && s.config.isMirrorEnabled)
            check(.ruleDouble, s.isWin && s.config.isDoubleTapEnabled)
            check(.ruleSplit, s.isWin && s.config.isSplittingEnabled)
            check(.ruleThreeHands, s.isWin && s.config.handCount == 3)
            check(.localDuel, s.mode == .localTwoPlayer)
            check(.multiplayerWin, (s.mode == .online || s.mode == .nearby) && s.isWin)
        }

        check(.streak3, stats.currentStreak >= 3)
        check(.streak5, stats.currentStreak >= 5)
        check(.streak10, stats.currentStreak >= 10)
        check(.rank5, stats.rankLevel >= 5)
        check(.rank10, stats.rankLevel >= GameStats.maxRankLevel)
        check(.maxWins10, stats.maxLevelWins >= 10)
        check(.daily1, stats.dailyChallengeClears >= 1)
        check(.daily7, stats.dailyChallengeClears >= 7)
        check(.days3, stats.dailyStreak >= 3)
        check(.days7, stats.dailyStreak >= 7)
        check(.days30, stats.dailyStreak >= 30)
        check(.games10, stats.totalGames >= 10)
        check(.games100, stats.totalGames >= 100)
        check(.level10, stats.playerLevel >= 10)
        check(.level20, stats.playerLevel >= 20)

        guard !newly.isEmpty else { return [] }
        let date = now()
        for a in newly { unlocked[a] = date }
        pendingToasts.append(contentsOf: newly)
        save()
        return newly
    }

    func reset() {
        unlocked = [:]
        pendingToasts = []
        defaults.removeObject(forKey: Self.key)
    }

    private func save() {
        var raw: [String: Date] = [:]
        for (a, d) in unlocked { raw[a.rawValue] = d }
        if let data = try? JSONEncoder().encode(raw) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
