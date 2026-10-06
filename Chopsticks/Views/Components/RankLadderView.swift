import SwiftUI

/// ランク戦の進行状況（Lv.1〜10の梯子と、現在のレベルで集めた★）
struct RankLadderView: View {
    let level: Int
    let stars: Int
    let starsRequired: Int
    var tint: Color = .orange

    private var isMax: Bool { level >= GameStats.maxRankLevel }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(1...GameStats.maxRankLevel, id: \.self) { n in
                    Capsule()
                        .fill(fill(for: n))
                        .frame(height: n == level ? 10 : 6)
                        .shadow(color: n == level ? tint.opacity(0.6) : .clear, radius: 4)
                }
            }
            .frame(height: 10)

            HStack(spacing: 6) {
                if isMax {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(AppTheme.goldGradient)
                    Text("最高レベル！ 何度でも挑戦できます")
                } else {
                    ForEach(0..<starsRequired, id: \.self) { i in
                        Image(systemName: i < stars ? "star.fill" : "star")
                            .font(.system(size: 12))
                            .foregroundStyle(i < stars ? tint : .white.opacity(0.3))
                    }
                    Text("あと\(starsRequired - stars)勝でLv.\(level + 1)")
                }
                Spacer(minLength: 0)
            }
            .font(.system(.caption, design: .rounded, weight: .medium))
            .foregroundStyle(.white.opacity(0.6))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isMax
            ? "ランク戦 最高レベル"
            : "ランク戦 レベル\(level)、あと\(starsRequired - stars)勝でレベル\(level + 1)")
    }

    private func fill(for n: Int) -> AnyShapeStyle {
        if n < level { return AnyShapeStyle(tint.opacity(0.55)) }
        if n == level { return AnyShapeStyle(tint) }
        return AnyShapeStyle(Color.white.opacity(0.12))
    }
}
