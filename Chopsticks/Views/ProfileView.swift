import SwiftUI

/// プレイヤーのレベル・戦績・実績の一覧
struct ProfileView: View {
    @State private var stats = GameStats.shared
    @State private var achievementStore = AchievementStore.shared
    @State private var gameCenter = GameCenterManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.bgDark.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        levelCard
                        rankCard
                        statsGrid
                        achievementsSection
                        if gameCenter.isAuthenticated {
                            Button {
                                gameCenter.showDashboard()
                            } label: {
                                Label("Game Centerでランキングを見る", systemImage: "list.number")
                            }
                            .buttonStyle(GlassButtonStyle(color: .green))
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("プロフィール")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }

    // MARK: - Cards

    private var levelCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Lv.\(stats.playerLevel)")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.accentGradient)
                Text(stats.playerTitle)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(stats.xp) XP")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            ProgressView(value: stats.levelProgress)
                .tint(AppTheme.accent)
            if let remaining = stats.xpToNextLevel {
                let next = PlayerLevel.nextTitleLevel(after: stats.playerLevel)
                HStack {
                    Text("次のレベルまで \(remaining) XP")
                    Spacer()
                    if let next {
                        Text("称号「\(PlayerLevel.title(forLevel: next))」はLv.\(next)")
                    }
                }
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
            } else {
                Text("最高レベルです！")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(18)
        .glassCard()
        .accessibilityElement(children: .combine)
    }

    private var rankCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("ランク戦", systemImage: "trophy.fill")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.orange)
            RankLadderView(level: stats.rankLevel, stars: stats.rankStars, starsRequired: stats.starsRequiredForCurrentLevel)
            if stats.isRankMaxed {
                Text("Lv.MAXでの勝利 \(stats.maxLevelWins)回")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var statsGrid: some View {
        let winRateText = stats.winRate.map { "\(Int(($0 * 100).rounded()))%" } ?? "-"
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
            tile("通算対戦", "\(stats.totalGames)", "gamecontroller.fill")
            tile("CPU戦 勝率", winRateText, "percent")
            tile("CPU戦 戦績", "\(stats.wins)勝\(stats.losses)敗", "flag.checkered")
            tile("ベスト連勝", "\(stats.bestStreak)", "flame.fill")
            tile("連続プレイ", "\(stats.effectiveDailyStreak)日", "calendar")
            tile("最長連続", "\(stats.bestDailyStreak)日", "calendar.badge.clock")
            tile("デイリークリア", "\(stats.dailyChallengeClears)回", "checkmark.seal.fill")
            tile("パーフェクト", "\(stats.perfectWins)回", "shield.checkered")
            tile("最短勝利", stats.fastestWinTurns.map { "\($0)ターン" } ?? "-", "bolt.fill")
            tile("対人戦 勝利", "\(stats.multiplayerWins)/\(stats.multiplayerGames)", "person.2.fill")
        }
    }

    private func tile(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.accent.opacity(0.8))
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 82)
        .padding(.vertical, 8)
        .glassCard(cornerRadius: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(value)")
    }

    // MARK: - Achievements

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("実績")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(achievementStore.unlockedCount) / \(achievementStore.totalCount)")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                ForEach(Achievement.allCases) { achievement in
                    achievementCell(achievement)
                }
            }
        }
    }

    private func achievementCell(_ achievement: Achievement) -> some View {
        let unlocked = achievementStore.isUnlocked(achievement)
        let hidden = achievement.isSecret && !unlocked
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: hidden ? "questionmark" : achievement.symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(unlocked ? AnyShapeStyle(AppTheme.goldGradient) : AnyShapeStyle(Color.white.opacity(0.3)))
                .frame(width: 34, height: 34)
                .background(Circle().fill(unlocked ? Color.yellow.opacity(0.15) : Color.white.opacity(0.06)))
            VStack(alignment: .leading, spacing: 2) {
                Text(hidden ? "ひみつの実績" : achievement.title)
                    .font(.system(.footnote, design: .rounded, weight: .bold))
                    .foregroundStyle(unlocked ? .white : .white.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(hidden ? "条件は秘密" : achievement.detail)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if unlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 14))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
        .glassCard(cornerRadius: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hidden ? "ひみつの実績。未解除" : "\(achievement.title)。\(achievement.detail)。\(unlocked ? "解除済み" : "未解除")")
    }
}

extension View {
    /// ガラス風のカード背景
    func glassCard(cornerRadius: CGFloat = 18) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(AppTheme.glassBorder, lineWidth: 0.5)
                )
        )
    }
}
