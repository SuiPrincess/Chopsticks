import SwiftUI

/// 戦績画面: ランク・CPU戦績・連勝・連続プレイ日数をまとめて表示
struct StatsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var stats = GameStats.shared
    @State private var showResetConfirm = false
    @State private var showGameCenter = false

    private var totalGames: Int { stats.wins + stats.losses }
    private var winRate: Int {
        guard totalGames > 0 else { return 0 }
        return Int((Double(stats.wins) / Double(totalGames) * 100).rounded())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.bgDark.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // ランク
                        statCard {
                            VStack(spacing: 12) {
                                HStack(spacing: 10) {
                                    Image(systemName: "trophy.fill")
                                        .font(.title2)
                                        .foregroundStyle(AppTheme.goldGradient)
                                    Text(stats.rankLevel >= GameStats.maxRankLevel
                                         ? String(localized: "ランク Lv.MAX")
                                         : String(localized: "ランク Lv.\(stats.rankLevel)"))
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                }

                                // ランク進行バー
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.white.opacity(0.08))
                                        Capsule()
                                            .fill(AppTheme.goldGradient)
                                            .frame(width: geo.size.width
                                                   * CGFloat(stats.rankLevel)
                                                   / CGFloat(GameStats.maxRankLevel))
                                    }
                                }
                                .frame(height: 8)

                                Text(stats.rankLevel >= GameStats.maxRankLevel
                                     ? String(localized: "全てのCPUを撃破！")
                                     : String(localized: "次はCPU Lv.\(stats.rankLevel)に挑戦"))
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }

                        // CPU戦績
                        statCard {
                            VStack(spacing: 14) {
                                sectionLabel("CPU対戦成績", icon: "cpu")
                                HStack(spacing: 0) {
                                    bigNumber("\(stats.wins)", label: "勝利", color: AppTheme.player1Color)
                                    bigNumber("\(stats.losses)", label: "敗北", color: AppTheme.player2Color)
                                    bigNumber(totalGames > 0 ? "\(winRate)%" : "—", label: "勝率", color: .white)
                                }
                                if stats.oniWins > 0 {
                                    Text("🔥 鬼撃破 \(stats.oniWins)回")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.orange.opacity(0.85))
                                }
                            }
                        }

                        // ストリーク
                        statCard {
                            VStack(spacing: 14) {
                                sectionLabel("ストリーク", icon: "flame.fill")
                                HStack(spacing: 0) {
                                    bigNumber("\(stats.currentStreak)", label: "連勝中", color: .orange)
                                    bigNumber("\(stats.bestStreak)", label: "ベスト連勝", color: .yellow)
                                    bigNumber("\(stats.dailyStreak)", label: "連続日数", color: .cyan)
                                }
                            }
                        }

                        // 今日の挑戦
                        statCard {
                            HStack(spacing: 12) {
                                Image(systemName: stats.isDailyChallengeClearedToday
                                      ? "checkmark.seal.fill"
                                      : "target")
                                    .font(.system(size: 22))
                                    .foregroundStyle(stats.isDailyChallengeClearedToday ? .cyan : .white.opacity(0.5))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("今日の挑戦 \(DailyChallenge.title())")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text(stats.isDailyChallengeClearedToday
                                         ? String(localized: "クリア済み！また明日！")
                                         : String(localized: "まだ未クリア。日替わりルールに挑もう"))
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.5))
                                    if stats.dailyChallengeClearCount > 0 {
                                        Text("通算クリア \(stats.dailyChallengeClearCount)回")
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundStyle(.cyan.opacity(0.7))
                                    }
                                    if stats.weeklyChallengeClearCount > 0 {
                                        Text("⚔️ 試練クリア \(stats.weeklyChallengeClearCount)回")
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundStyle(.purple.opacity(0.85))
                                    }
                                }
                                Spacer()
                            }
                        }

                        if GameCenterManager.shared.isAuthenticated {
                            Button {
                                showGameCenter = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "gamecontroller.fill")
                                    Text("Game Centerを見る")
                                }
                            }
                            .buttonStyle(GlassButtonStyle(color: .green, isPrimary: false))
                        }

                        if totalGames > 0 {
                            Button {
                                showResetConfirm = true
                            } label: {
                                Text("戦績をリセット")
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("戦績")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .sheet(isPresented: $showGameCenter) {
                GameCenterDashboardView(onDismiss: { showGameCenter = false })
                    .ignoresSafeArea()
            }
            .alert("戦績をリセットしますか？", isPresented: $showResetConfirm) {
                Button("リセット", role: .destructive) {
                    GameStats.shared.reset()
                    // 中断中のランク戦セーブはリセット前のレベルを持っているため破棄する
                    if GameSessionStore.shared.savedGame?.state.config.aiLevel != nil {
                        GameSessionStore.shared.clear()
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("勝敗・連勝記録・ランクの進行が全て初期化されます。この操作は取り消せません。")
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Components

    @ViewBuilder
    private func sectionLabel(_ title: LocalizedStringKey, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(title)
                .tracking(1)
                .textCase(.uppercase)
        }
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .foregroundStyle(AppTheme.accent.opacity(0.8))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func bigNumber(_ value: String, label: LocalizedStringKey, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func statCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack {
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.glassBorder, lineWidth: 0.5)
                )
        )
    }
}
