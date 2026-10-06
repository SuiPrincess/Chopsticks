import Foundation

/// 「先手でも後手でも、序盤で一方的に勝ちが決まらない」ことを全探索で確かめたルールの組み合わせ
/// （検証は `RuleFairnessTests`）。デイリーチャレンジとおまかせルールはここから選ぶ。
///
/// 爆弾の単独使用・クラシック（ループなし）などは、先手か後手が数手で勝ちを強制できてしまうため含めない。
/// 自分で設定する分には自由に選べる。
enum FairRuleSets {
    enum Rule: String, CaseIterable {
        case poison, mirror, double, split, revival, three

        var label: String {
            switch self {
            case .poison: "毒"
            case .mirror: "ミラー"
            case .double: "連撃"
            case .split: "分割"
            case .revival: "復活"
            case .three: "三本手"
            }
        }
    }

    static let all: [Set<Rule>] = [
        [.mirror],
        [.split],
        [.split, .revival],
        [.three],
        [.poison, .mirror],
        [.poison, .split, .revival],
        [.mirror, .double],
        [.mirror, .split],
        [.mirror, .split, .revival],
        [.mirror, .three],
        [.double, .split],
        [.split, .three],
        [.split, .three, .revival],
    ]

    /// ルールを設定に反映する（ループありに固定。モードや難易度は変えない）
    static func apply(_ rules: Set<Rule>, to config: inout GameConfig) {
        config.isOverflowWrapEnabled = true
        config.isPoisonEnabled = rules.contains(.poison)
        config.isMirrorEnabled = rules.contains(.mirror)
        config.isDoubleTapEnabled = rules.contains(.double)
        config.isBombEnabled = false
        config.isSplittingEnabled = rules.contains(.split)
        config.isDeadHandRevivalEnabled = rules.contains(.revival)
        config.handCount = rules.contains(.three) ? 3 : 2
    }

    /// 表示用の名前（例: 「ミラー×分割」）
    static func name(for rules: Set<Rule>) -> String {
        Rule.allCases.filter { rules.contains($0) }.map(\.label).joined(separator: "×")
    }
}
