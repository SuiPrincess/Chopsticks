import SwiftUI
import GameKit

struct MenuView: View {
    @State private var config = GameConfig()
    @State private var showRuleSettings = false
    @State private var showRuleConfirmation = false
    @State private var showAIDifficultyPicker = false
    @State private var showStats = false
    @State private var showSettings = false
    @State private var showShop = false
    @State private var storeManager = StoreManager.shared
    @State private var navigateToGame = false
    @State private var titleGlow: CGFloat = 0.3

    // 前の画面の閉じるアニメーション完了後（onDismiss）に次を出すためのフラグ。
    // 同時にpresentすると遷移が無視されることがある。
    @State private var pendingRuleConfirmation = false
    @State private var pendingGameStart = false

    /// ランク戦用の固定設定。非nilのときはユーザーのルール設定より優先する。
    /// ルール設定の影響を受けると毒ルール等でランクが攻略できてしまうため。
    @State private var rankedConfig: GameConfig?

    private var activeConfig: GameConfig { rankedConfig ?? config }

    /// ランク戦は標準ルール固定（ループあり・分割なし・特殊ルールなし）
    private static func makeRankedConfig() -> GameConfig {
        var rankedConfig = GameConfig()
        rankedConfig.gameMode = .vsAI
        rankedConfig.aiLevel = GameStats.shared.rankLevel
        return rankedConfig
    }

    // Multiplayer
    @State private var showNearbyMatch = false
    @State private var showGameKitMatchmaker = false
    @State private var multiplayerService: (any MultiplayerService)?
    @State private var gameCenterManager = GameCenterManager.shared

    // 中断ゲームの再開
    @State private var sessionStore = GameSessionStore.shared
    @State private var resumeGame: SavedGame?

    // タイトル下の飾り手（時々指の本数が変わる）
    @State private var decorLeftCount = 3
    @State private var decorRightCount = 2

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundGradientView()

                // 「続きから」表示時など縦に収まらない小型端末ではスクロール可能にする
                ViewThatFits(in: .vertical) {
                    menuContent
                    ScrollView {
                        menuContent
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 10) {
                    Button {
                        showShop = true
                    } label: {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(
                                storeManager.isPremium
                                    ? AnyShapeStyle(AppTheme.goldGradient)
                                    : AnyShapeStyle(Color.yellow.opacity(0.75))
                            )
                            .frame(width: 38, height: 38)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(Circle().stroke(Color.yellow.opacity(0.25), lineWidth: 0.5))
                            )
                    }
                    .accessibilityLabel("ショップ")

                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.45))
                            .frame(width: 38, height: 38)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                            )
                    }
                    .accessibilityLabel("設定")
                }
                .padding(.trailing, 20)
                .padding(.top, 8)
            }
            .navigationDestination(isPresented: $navigateToGame) {
                GameView(
                    config: resumeGame?.state.config ?? activeConfig,
                    multiplayerService: multiplayerService,
                    savedGame: resumeGame
                )
                .navigationBarBackButtonHidden()
                .onDisappear {
                    multiplayerService = nil
                    resumeGame = nil
                }
            }
            .sheet(isPresented: $showRuleSettings) {
                RuleSettingsView(config: $config)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showStats) {
                StatsView()
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showShop) {
                ShopView()
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
                .presentationDetents([.medium, .large])
            }
            .fullScreenCover(isPresented: $showRuleConfirmation, onDismiss: {
                if pendingGameStart {
                    pendingGameStart = false
                    navigateToGame = true
                } else {
                    // ルール確認をキャンセルした場合の後始末。
                    // 接続済みのマルチプレイサービスを放置すると、
                    // 次に始める無関係なゲームに付着してしまう
                    if let service = multiplayerService {
                        service.disconnect()
                        multiplayerService = nil
                    }
                    rankedConfig = nil
                }
            }) {
                RuleDisplayView(
                    config: activeConfig,
                    isPreGame: true,
                    onStart: {
                        pendingGameStart = true
                        showRuleConfirmation = false
                    },
                    onDismiss: { showRuleConfirmation = false }
                )
            }
            .fullScreenCover(isPresented: $showNearbyMatch) {
                NearbyMatchView(
                    config: $config,
                    onConnected: { service in
                        multiplayerService = service
                        showNearbyMatch = false
                        showRuleConfirmation = true
                    },
                    onCancel: { showNearbyMatch = false }
                )
            }
            .sheet(isPresented: $showGameKitMatchmaker) {
                GameKitMatchmakerView(
                    onMatchFound: { match in
                        let service = GameKitService()
                        service.configure(with: match)
                        multiplayerService = service
                        showGameKitMatchmaker = false
                        showRuleConfirmation = true
                    },
                    onCancel: { showGameKitMatchmaker = false }
                )
            }
        }
        .onAppear {
            withAnimation(Anim.glowPulse) { titleGlow = 0.8 }
            GameCenterManager.shared.authenticateLocalPlayer()
            SoundManager.prepare()
        }
    }

    // MARK: - Menu content

    private var menuContent: some View {
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
            .padding(.top, 30)

            Spacer()

            // Hand decoration
            HStack(spacing: 40) {
                decorationHand(count: decorLeftCount, color: AppTheme.player1Color)
                decorationHand(count: decorRightCount, color: AppTheme.player2Color)
            }
            .padding(.bottom, 40)
            .task {
                // ゆっくり指の本数が変わり、対戦している雰囲気を出す
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(2.2))
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        decorLeftCount = Int.random(in: 1...4)
                        decorRightCount = Int.random(in: 1...4)
                    }
                }
            }

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                // 中断したゲームの再開
                if let saved = sessionStore.savedGame,
                   let description = sessionStore.resumeDescription {
                    Button {
                        resumeGame = saved
                        navigateToGame = true
                    } label: {
                        VStack(spacing: 3) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.uturn.forward.circle.fill")
                                Text("続きから")
                            }
                            Text(description)
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }
                    .buttonStyle(GlassButtonStyle(color: .cyan))
                }

                // ランク戦（メインの進行ループ・固定標準ルール）
                Button {
                    rankedConfig = Self.makeRankedConfig()
                    showRuleConfirmation = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                        Text(rankButtonLabel)
                    }
                }
                .buttonStyle(GlassButtonStyle(color: .orange))

                // 🎯 今日の挑戦（日替わりルール・全ユーザー共通・1日1回クリア記録）
                Button {
                    rankedConfig = DailyChallenge.config()
                    showRuleConfirmation = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: GameStats.shared.isDailyChallengeClearedToday
                              ? "checkmark.seal.fill"
                              : "target")
                        Text("今日の挑戦 — \(DailyChallenge.title())")
                        if GameStats.shared.isDailyChallengeClearedToday {
                            Text("クリア済")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.cyan))
                        }
                    }
                }
                .buttonStyle(GlassButtonStyle(color: .cyan))

                // 2P Local
                Button {
                    rankedConfig = nil
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
                    rankedConfig = nil
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

                // Nearby (Multipeer)
                Button {
                    rankedConfig = nil
                    config.gameMode = .nearby
                    config.aiLevel = nil
                    showNearbyMatch = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text("近くの人と対戦")
                    }
                }
                .buttonStyle(GlassButtonStyle(color: .green))

                // Online (Game Center)
                Button {
                    rankedConfig = nil
                    config.gameMode = .online
                    config.aiLevel = nil
                    showGameKitMatchmaker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                        Text("オンライン対戦")
                    }
                }
                .buttonStyle(GlassButtonStyle(color: .orange))
                .opacity(gameCenterManager.isAuthenticated ? 1 : 0.4)
                .disabled(!gameCenterManager.isAuthenticated)

                // Rules + random rules + stats
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
                    .accessibilityLabel("おまかせルール")

                    Button {
                        showStats = true
                    } label: {
                        Image(systemName: "chart.bar.fill")
                    }
                    .buttonStyle(GlassButtonStyle(color: .cyan, isPrimary: false))
                    .frame(width: 64)
                    .accessibilityLabel("戦績")
                }

                statsIndicator
                activeRulesIndicator

                if !gameCenterManager.isAuthenticated {
                    Text("Game Centerにログインするとオンライン対戦が可能")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
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
