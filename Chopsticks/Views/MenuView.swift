import SwiftUI

struct MenuView: View {
    @State private var config = GameConfig()
    @State private var showRuleSettings = false
    @State private var showRuleConfirmation = false
    @State private var showAIDifficultyPicker = false
    @State private var navigateToGame = false
    @State private var titleGlow: CGFloat = 0.3

    // 前の画面の閉じるアニメーション完了後（onDismiss）に次を出すためのフラグ。
    // 同時にpresentすると遷移が無視されることがある。
    @State private var pendingRuleConfirmation = false
    @State private var pendingGameStart = false

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundGradientView()

                VStack(spacing: 0) {
                    Spacer()

                    // Title
                    VStack(spacing: 12) {
                        Text("CHOPSTICKS")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppTheme.accent, AppTheme.accentSecondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: AppTheme.accent.opacity(titleGlow), radius: 20)
                            .shadow(color: AppTheme.accentSecondary.opacity(titleGlow * 0.5), radius: 40)

                        Text("waribashi")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                            .tracking(8)
                    }

                    Spacer()

                    // Hand decoration
                    HStack(spacing: 40) {
                        decorationHand(count: 3, color: AppTheme.player1Color)
                        decorationHand(count: 2, color: AppTheme.player2Color)
                    }
                    .padding(.bottom, 40)

                    Spacer()

                    // Buttons
                    VStack(spacing: 12) {
                        // 2P Local
                        // ランク戦（メインの進行ループ）
                        Button {
                            config.gameMode = .vsAI
                            config.aiLevel = GameStats.shared.rankLevel
                            showRuleConfirmation = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "trophy.fill")
                                Text(rankButtonLabel)
                            }
                        }
                        .buttonStyle(GlassButtonStyle(color: .orange))

                        Button {
                            config.gameMode = .localTwoPlayer
                            config.aiLevel = nil
                            showRuleConfirmation = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "person.2.fill")
                                Text("2人対戦")
                            }
                        }
                        .buttonStyle(GlassButtonStyle())

                        // VS AI (フリー対戦)
                        Button {
                            config.gameMode = .vsAI
                            config.aiLevel = nil
                            showAIDifficultyPicker = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "cpu")
                                Text("フリー対戦")
                            }
                        }
                        .buttonStyle(GlassButtonStyle(color: AppTheme.accentSecondary))

                        // Rules + random rules
                        HStack(spacing: 12) {
                            Button {
                                showRuleSettings = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "gearshape")
                                    Text("ルール設定")
                                }
                            }
                            .buttonStyle(GlassButtonStyle(isPrimary: false))

                            Button {
                                randomizeRules()
                            } label: {
                                Image(systemName: "dice.fill")
                            }
                            .buttonStyle(GlassButtonStyle(color: .orange))
                            .frame(width: 64)
                        }

                        statsIndicator
                        activeRulesIndicator
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 50)
                }
            }
            .navigationDestination(isPresented: $navigateToGame) {
                GameView(config: config)
                    .navigationBarBackButtonHidden()
            }
            .sheet(isPresented: $showRuleSettings) {
                RuleSettingsView(config: $config)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showAIDifficultyPicker, onDismiss: {
                if pendingRuleConfirmation {
                    pendingRuleConfirmation = false
                    showRuleConfirmation = true
                }
            }) {
                AIDifficultyPickerView(
                    difficulty: $config.aiDifficulty,
                    onStart: {
                        pendingRuleConfirmation = true
                        showAIDifficultyPicker = false
                    }
                )
                .presentationDetents([.medium])
            }
            .fullScreenCover(isPresented: $showRuleConfirmation, onDismiss: {
                if pendingGameStart {
                    pendingGameStart = false
                    navigateToGame = true
                }
            }) {
                RuleDisplayView(
                    config: config,
                    isPreGame: true,
                    onStart: {
                        pendingGameStart = true
                        showRuleConfirmation = false
                    },
                    onDismiss: { showRuleConfirmation = false }
                )
            }
        }
        .onAppear {
            withAnimation(Anim.glowPulse) { titleGlow = 0.8 }
        }
    }

    /// 特殊ルールをランダムに組み合わせて毎回違うゲームにする
    private func randomizeRules() {
        func chance(_ probability: Double) -> Bool {
            Double.random(in: 0..<1) < probability
        }

        var newConfig = config
        newConfig.isOverflowWrapEnabled = chance(0.7)
        newConfig.isSplittingEnabled = chance(0.5)
        newConfig.isDeadHandRevivalEnabled = newConfig.isSplittingEnabled && chance(0.4)
        newConfig.handCount = chance(0.25) ? 3 : 2
        newConfig.isPoisonEnabled = chance(0.3)
        newConfig.isBombEnabled = chance(0.3)
        newConfig.isMirrorEnabled = chance(0.3)
        newConfig.isDoubleTapEnabled = chance(0.3)

        // 全部OFFの退屈な結果は避け、どれか1つは必ず入れる
        if !newConfig.isSplittingEnabled && !newConfig.isPoisonEnabled
            && !newConfig.isBombEnabled && !newConfig.isMirrorEnabled
            && !newConfig.isDoubleTapEnabled {
            switch Int.random(in: 0..<5) {
            case 0: newConfig.isSplittingEnabled = true
            case 1: newConfig.isPoisonEnabled = true
            case 2: newConfig.isBombEnabled = true
            case 3: newConfig.isMirrorEnabled = true
            default: newConfig.isDoubleTapEnabled = true
            }
        }

        withAnimation(.spring(response: 0.3)) { config = newConfig }
        HapticManager.split()
    }

    private var rankButtonLabel: String {
        let level = GameStats.shared.rankLevel
        return level >= GameStats.maxRankLevel
            ? "ランク戦 Lv.MAX"
            : "ランク戦 — Lv.\(level)に挑戦"
    }

    @ViewBuilder
    private var statsIndicator: some View {
        let stats = GameStats.shared
        if stats.wins + stats.losses > 0 {
            HStack(spacing: 8) {
                if stats.dailyStreak >= 2 {
                    Text("🗓️ \(stats.dailyStreak)日連続")
                        .foregroundStyle(.cyan)
                }
                if stats.currentStreak >= 2 {
                    Text("🔥 \(stats.currentStreak)連勝中")
                        .foregroundStyle(.orange)
                }
                Text("CPU戦 \(stats.wins)勝 \(stats.losses)敗")
                Text("ベスト連勝 \(stats.bestStreak)")
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.45))
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var activeRulesIndicator: some View {
        let labels = activeRuleLabels
        if !labels.isEmpty {
            HStack(spacing: 6) {
                ForEach(labels, id: \.self) { label in
                    HStack(spacing: 3) {
                        Circle().fill(.green).frame(width: 5, height: 5)
                        Text(label)
                    }
                }
            }
            .font(.system(size: 11, design: .rounded))
            .foregroundStyle(.white.opacity(0.45))
            .padding(.top, 4)
        }
    }

    private var activeRuleLabels: [String] {
        var labels: [String] = []
        if config.isOverflowWrapEnabled { labels.append("ループ") }
        if config.isSplittingEnabled { labels.append("分割") }
        if config.isDeadHandRevivalEnabled { labels.append("復活") }
        if config.handCount == 3 { labels.append("3本手") }
        if config.isPoisonEnabled { labels.append("毒") }
        if config.isBombEnabled { labels.append("爆弾") }
        if config.isMirrorEnabled { labels.append("ミラー") }
        if config.isDoubleTapEnabled { labels.append("2回攻撃") }
        return labels
    }

    @ViewBuilder
    private func decorationHand(count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(i < count ? color.opacity(0.6) : Color.white.opacity(0.05))
                    .frame(width: 10, height: i < count ? 30 : 16)
                    .shadow(color: i < count ? color.opacity(0.3) : .clear, radius: 4)
            }
        }
    }
}
