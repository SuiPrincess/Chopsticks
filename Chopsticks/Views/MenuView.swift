import SwiftUI
import GameKit

/// ゲーム画面に渡す起動内容
struct GameLaunch {
    enum Kind {
        case new(GameConfig)
        case resume(SavedGame)
    }

    var kind: Kind
    var service: (any MultiplayerService)?
}

struct MenuView: View {
    @State private var settings = AppSettings.shared
    @State private var stats = GameStats.shared
    @State private var gameCenter = GameCenterManager.shared

    /// 2人対戦・フリー対戦・対人戦で使うルール（端末に保存される）
    @State private var customRules: GameConfig

    @State private var launch: GameLaunch?
    @State private var navigateToGame = false
    @State private var savedGame: SavedGame?

    // 前の画面を閉じ終えてから次を出すためのチェーン。
    // 同時にdismissとpresentを行うと遷移が無視されることがあるため、必ずonDismissで次へ進む。
    @State private var afterDismiss: (() -> Void)?
    @State private var pendingConfig: GameConfig?
    @State private var pendingConfirmKey: String?
    @State private var pendingConfirmTitle: String?

    @State private var showRuleSettings = false
    @State private var showRuleConfirmation = false
    @State private var showAIDifficultyPicker = false
    @State private var showNearbyMatch = false
    @State private var showGameKitMatchmaker = false
    @State private var showSettings = false
    @State private var showProfile = false
    @State private var showHowToPlay = false
    @State private var showGameCenterAlert = false
    /// オンライン対戦を押してGame Centerのサインイン完了を待っている
    @State private var wantsOnline = false
    /// 相手の接続が完了するまで保持するGame Centerの対戦サービス
    @State private var pendingGameKitService: GameKitService?
    @State private var onlineHint: String?

    @State private var diceMessage: String?
    @State private var diceToken = 0
    @State private var titleGlow: CGFloat = 0.3
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    init() {
        _customRules = State(initialValue: AppSettings.shared.loadCustomRules())
    }

    private var reducesMotion: Bool { systemReduceMotion || settings.reducesEffects }

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundGradientView()

                ScrollView {
                    VStack(spacing: 16) {
                        topBar
                        titleBlock
                        rankCard
                        if let savedGame { resumeCard(savedGame) }
                        dailyCard
                        modeButtons
                        rulesRow
                        statsIndicator
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .frame(maxWidth: 480)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $navigateToGame) { gameDestination }
            .sheet(isPresented: $showRuleSettings) {
                RuleSettingsView(config: $customRules)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showAIDifficultyPicker, onDismiss: runAfterDismiss) {
                AIDifficultyPickerView(
                    difficulty: $customRules.aiDifficulty,
                    onStart: {
                        afterDismiss = { startFreePlay() }
                        showAIDifficultyPicker = false
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $showRuleConfirmation, onDismiss: runAfterDismiss) {
                RuleDisplayView(
                    config: pendingConfig ?? customRules,
                    isPreGame: true,
                    title: pendingConfirmTitle,
                    onStart: {
                        settings.lastConfirmedRulesKey = pendingConfirmKey
                        afterDismiss = {
                            if let config = pendingConfig { start(.new(config)) }
                        }
                        showRuleConfirmation = false
                    },
                    onDismiss: { showRuleConfirmation = false }
                )
            }
            .fullScreenCover(isPresented: $showNearbyMatch, onDismiss: runAfterDismiss) {
                NearbyMatchView(
                    onConnected: { service in
                        afterDismiss = { startMultiplayer(.nearby, service: service) }
                        showNearbyMatch = false
                    },
                    onCancel: { showNearbyMatch = false }
                )
            }
            .sheet(isPresented: $showGameKitMatchmaker, onDismiss: {
                // 接続完了を待つ間にシートが閉じられたら、取り残しの対戦を破棄する
                if let pending = pendingGameKitService {
                    pending.onConnectionChanged = nil
                    pending.disconnect()
                    pendingGameKitService = nil
                }
                runAfterDismiss()
            }) {
                GameKitMatchmakerView(
                    onMatchFound: { match in handleMatchFound(match) },
                    onCancel: { showGameKitMatchmaker = false }
                )
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
                    .presentationDetents([.large])
            }
            .fullScreenCover(isPresented: $showHowToPlay) {
                HowToPlayView(onFinish: {
                    settings.hasSeenTutorial = true
                    showHowToPlay = false
                })
            }
            .alert("Game Centerにサインインしてください", isPresented: $showGameCenterAlert) {
                Button("設定を開く") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("閉じる", role: .cancel) {}
            } message: {
                Text("設定アプリの「Game Center」でサインインすると、オンライン対戦が遊べます。")
            }
        }
        .onAppear {
            refreshSavedGame()
            if !reducesMotion {
                withAnimation(Anim.glowPulse) { titleGlow = 0.8 }
            }
        }
        .task {
            // 初回起動は遊び方から（一度見たら二度と自動では出さない）
            if !settings.hasSeenTutorial && !stats.hasPlayed {
                showHowToPlay = true
            }
        }
        .onChange(of: customRules) { _, rules in
            settings.saveCustomRules(rules)
        }
        .onChange(of: navigateToGame) { _, isActive in
            if !isActive { refreshSavedGame() }
        }
        .onChange(of: gameCenter.isAuthenticated) { _, authenticated in
            if authenticated && wantsOnline {
                wantsOnline = false
                onlineHint = nil
                showGameKitMatchmaker = true
            }
        }
        .onChange(of: gameCenter.didFinishAuthentication) { _, finished in
            if finished && wantsOnline && !gameCenter.isAuthenticated {
                wantsOnline = false
                onlineHint = nil
                showGameCenterAlert = true
            }
        }
    }

    // MARK: - 遷移

    @ViewBuilder
    private var gameDestination: some View {
        if let launch {
            Group {
                switch launch.kind {
                case .new(let config):
                    GameView(config: config, multiplayerService: launch.service)
                case .resume(let saved):
                    GameView(savedGame: saved)
                }
            }
            .navigationBarBackButtonHidden()
            .toolbar(.hidden, for: .navigationBar)
            .onDisappear {
                self.launch = nil
                refreshSavedGame()
            }
        }
    }

    private func start(_ kind: GameLaunch.Kind, service: (any MultiplayerService)? = nil) {
        launch = GameLaunch(kind: kind, service: service)
        navigateToGame = true
    }

    private func runAfterDismiss() {
        guard let action = afterDismiss else { return }
        afterDismiss = nil
        action()
    }

    private func refreshSavedGame() {
        savedGame = GameSessionStore.load()
    }

    /// ルールの組み合わせが前回確認したものと同じなら、確認画面を省略して直接始める
    private func confirmThenStart(_ config: GameConfig, title: String? = nil) {
        let key = rulesKey(config)
        if settings.lastConfirmedRulesKey == key {
            start(.new(config))
        } else {
            pendingConfig = config
            pendingConfirmKey = key
            pendingConfirmTitle = title
            showRuleConfirmation = true
        }
    }

    private func rulesKey(_ config: GameConfig) -> String {
        "\(config.gameMode.rawValue)|\(config.activeRuleLabels.joined(separator: ","))|\(config.isDailyChallenge ? "daily" : "")"
    }

    // MARK: - 各モードの開始

    private func startRanked() {
        var config = GameConfig()
        config.gameMode = .vsAI
        config.aiLevel = stats.rankLevel
        // ランク戦は標準ルール固定。確認画面は出さずにすぐ始める。
        start(.new(config))
    }

    private func startDaily() {
        let challenge = stats.todaysChallenge
        confirmThenStart(challenge.config, title: "今日のチャレンジ「\(challenge.title)」")
    }

    private func startLocal() {
        var config = customRules
        config.gameMode = .localTwoPlayer
        config.aiLevel = nil
        config.isDailyChallenge = false
        confirmThenStart(config)
    }

    private func startFreePlay() {
        var config = customRules
        config.gameMode = .vsAI
        config.aiLevel = nil
        config.isDailyChallenge = false
        confirmThenStart(config)
    }

    private func startMultiplayer(_ mode: GameMode, service: any MultiplayerService) {
        // ルールはホストのものが使われる（ゲーム画面で双方に表示される）
        var config = customRules
        config.gameMode = mode
        config.aiLevel = nil
        config.isDailyChallenge = false
        start(.new(config), service: service)
    }

    private func tapOnline() {
        if gameCenter.isAuthenticated {
            showGameKitMatchmaker = true
        } else if gameCenter.didFinishAuthentication {
            // 認証を試みた結果、未サインイン: 設定アプリへ案内する
            showGameCenterAlert = true
        } else {
            // サインイン処理中（または未開始）: 終わりしだい自動でマッチングへ進む
            wantsOnline = true
            onlineHint = "Game Centerに接続しています…"
            gameCenter.authenticateLocalPlayer()
        }
    }

    /// 対戦相手が見つかったら、相手の接続が完了（ホスト確定）してから画面を進める
    private func handleMatchFound(_ match: GKMatch) {
        let service = GameKitService()
        service.configure(with: match)
        if service.isConnected {
            proceedWithMatch(service)
        } else {
            pendingGameKitService = service
            service.onConnectionChanged = { [weak service] connected in
                guard let service else { return }
                if connected {
                    proceedWithMatch(service)
                } else {
                    pendingGameKitService = nil
                    service.disconnect()
                    showGameKitMatchmaker = false
                }
            }
        }
    }

    private func proceedWithMatch(_ service: GameKitService) {
        service.onConnectionChanged = nil
        pendingGameKitService = nil
        // 待っている間にシートが閉じられていたら、取り残しの遷移を作らずに接続を捨てる
        guard showGameKitMatchmaker else {
            service.disconnect()
            return
        }
        afterDismiss = { startMultiplayer(.online, service: service) }
        showGameKitMatchmaker = false
    }

    // MARK: - パーツ

    private var topBar: some View {
        HStack(spacing: 8) {
            Button {
                showProfile = true
            } label: {
                HStack(spacing: 8) {
                    Text("Lv.\(stats.playerLevel)")
                        .font(.system(.footnote, design: .rounded, weight: .heavy))
                        .foregroundStyle(AppTheme.accent)
                    Text(stats.playerTitle)
                        .font(.system(.footnote, design: .rounded, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                    ProgressView(value: stats.levelProgress)
                        .tint(AppTheme.accent)
                        .frame(width: 40)
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(Capsule().fill(.ultraThinMaterial))
            }
            .accessibilityLabel("プロフィール。レベル\(stats.playerLevel)、称号\(stats.playerTitle)")

            Spacer()

            CircleIconButton(systemName: "questionmark", label: "遊び方") { showHowToPlay = true }
            CircleIconButton(systemName: "gearshape.fill", label: "設定") { showSettings = true }
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 10) {
            Text("CHOPSTICKS")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppTheme.accent, AppTheme.accentSecondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: AppTheme.accent.opacity(titleGlow), radius: 20)
                .shadow(color: AppTheme.accentSecondary.opacity(titleGlow * 0.5), radius: 40)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text("割り箸バトル")
                .font(.system(.footnote, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(6)

            HStack(spacing: 28) {
                FingerRow(count: 3, color: AppTheme.player1Color, small: true)
                FingerRow(count: 2, color: AppTheme.player2Color, small: true)
            }
            .padding(.top, 2)
            .accessibilityHidden(true)

            Text("指をたたいて、手を5にしたら勝ち！")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.vertical, 6)
    }

    private var rankCard: some View {
        Button {
            startRanked()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(AppTheme.goldGradient)
                    Text(stats.isRankMaxed ? "ランク戦 Lv.MAX" : "ランク戦 Lv.\(stats.rankLevel)に挑戦")
                        .font(.system(.headline, design: .rounded, weight: .heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                }
                RankLadderView(level: stats.rankLevel, stars: stats.rankStars, starsRequired: stats.starsRequiredForCurrentLevel)
                if !stats.hasPlayed {
                    Text("はじめての方はここから！ 標準ルールのCPU戦で、1勝すればLv.2です")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .buttonStyle(CardButtonStyle(color: .orange))
    }

    private func resumeCard(_ saved: SavedGame) -> some View {
        Button {
            start(.resume(saved))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("続きから遊ぶ")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text(resumeSubtitle(saved))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("別の対戦を始めると、この対戦は破棄されます")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .buttonStyle(CardButtonStyle(color: .green))
    }

    private func resumeSubtitle(_ saved: SavedGame) -> String {
        let config = saved.state.config
        let kind: String
        if config.isDailyChallenge {
            kind = "デイリーチャレンジ"
        } else if config.isRanked, let level = config.aiLevel {
            kind = "ランク戦 Lv.\(level)"
        } else if config.gameMode == .vsAI {
            kind = "フリー対戦"
        } else {
            kind = "2人対戦"
        }
        return "\(kind) ・ \(saved.state.turnCount + 1)ターン目"
    }

    private var dailyCard: some View {
        let challenge = stats.todaysChallenge
        let cleared = stats.hasClearedTodaysChallenge
        return Button {
            startDaily()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: cleared ? "checkmark.seal.fill" : "calendar.badge.exclamationmark")
                    .font(.title2)
                    .foregroundStyle(cleared ? Color.green : Color.cyan)
                VStack(alignment: .leading, spacing: 3) {
                    Text("今日のチャレンジ")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.cyan.opacity(0.9))
                    Text(challenge.title)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("CPU Lv.\(challenge.cpuLevel) ・ \(challenge.config.activeRuleLabels.joined(separator: " "))")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer()
                Text(cleared ? "クリア済み" : "+\(DailyChallenge.bonusXP)XP")
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .foregroundStyle(cleared ? Color.green : Color.cyan)
            }
        }
        .buttonStyle(CardButtonStyle(color: .cyan))
        .accessibilityLabel("今日のチャレンジ、\(challenge.title)、CPUレベル\(challenge.cpuLevel)、\(cleared ? "クリア済み" : "クリアすると\(DailyChallenge.bonusXP)経験値")")
    }

    private var modeButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                modeButton("2人対戦", icon: "person.2.fill", color: AppTheme.accent) { startLocal() }
                modeButton("フリー対戦", icon: "cpu", color: AppTheme.accentSecondary) { showAIDifficultyPicker = true }
            }
            HStack(spacing: 12) {
                modeButton("近くの人と", icon: "antenna.radiowaves.left.and.right", color: .green) { showNearbyMatch = true }
                modeButton("オンライン", icon: "globe", color: .orange) { tapOnline() }
            }
            if let onlineHint {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.7).tint(.white.opacity(0.6))
                    Text(onlineHint)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }

    private func modeButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(GlassButtonStyle(color: color))
    }

    private var rulesRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    showRuleSettings = true
                } label: {
                    Label("ルール設定", systemImage: "gearshape")
                }
                .buttonStyle(GlassButtonStyle(isPrimary: false))

                Button {
                    randomizeRules()
                } label: {
                    Label("おまかせ", systemImage: "dice.fill")
                }
                .buttonStyle(GlassButtonStyle(color: .orange))
                .accessibilityLabel("おまかせルール。特殊ルールをランダムに決める")
            }

            if let diceMessage {
                Text(diceMessage)
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            FlowLayout(spacing: 10, rowSpacing: 4) {
                ForEach(customRules.activeRuleLabels, id: \.self) { label in
                    HStack(spacing: 3) {
                        Circle().fill(.green).frame(width: 5, height: 5)
                        Text(label)
                    }
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                }
            }

            Text("このルールは2人対戦・フリー対戦・対人戦で使われます。ランク戦は標準ルール固定です")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
        }
        .task(id: diceToken) {
            guard diceMessage != nil else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation { diceMessage = nil }
        }
    }

    @ViewBuilder
    private var statsIndicator: some View {
        if stats.hasPlayed {
            FlowLayout(spacing: 10, rowSpacing: 4) {
                if stats.effectiveDailyStreak >= 2 {
                    chip("🗓️ \(stats.effectiveDailyStreak)日連続", color: .cyan)
                } else if stats.isDailyStreakAtRisk {
                    chip("今日遊ぶと連続記録が続きます", color: .cyan)
                }
                if stats.currentStreak >= 2 {
                    chip("🔥 \(stats.currentStreak)連勝中", color: .orange)
                }
                chip("CPU戦 \(stats.wins)勝\(stats.losses)敗", color: .white.opacity(0.55))
                chip("ベスト連勝 \(stats.bestStreak)", color: .white.opacity(0.55))
            }
            .padding(.top, 4)
        }
    }

    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(.caption, design: .rounded, weight: .medium))
            .foregroundStyle(color)
    }

    /// 特殊ルールをランダムに組み合わせて毎回違うゲームにする
    private func randomizeRules() {
        func chance(_ probability: Double) -> Bool {
            Double.random(in: 0..<1) < probability
        }

        var newConfig = customRules
        newConfig.isOverflowWrapEnabled = chance(0.7)
        newConfig.isSplittingEnabled = chance(0.5)
        newConfig.isDeadHandRevivalEnabled = newConfig.isSplittingEnabled && chance(0.4)
        newConfig.handCount = chance(0.25) ? 3 : 2
        newConfig.isPoisonEnabled = chance(0.3)
        newConfig.isBombEnabled = chance(0.3)
        newConfig.isMirrorEnabled = chance(0.3)
        newConfig.isDoubleTapEnabled = chance(0.3)

        // 全部OFFの退屈な結果は避け、どれか1つは必ず入れる
        if !newConfig.hasSpecialRules && !newConfig.isSplittingEnabled {
            switch Int.random(in: 0..<5) {
            case 0: newConfig.isSplittingEnabled = true
            case 1: newConfig.isPoisonEnabled = true
            case 2: newConfig.isBombEnabled = true
            case 3: newConfig.isMirrorEnabled = true
            default: newConfig.isDoubleTapEnabled = true
            }
        }

        withAnimation(.spring(response: 0.3)) {
            customRules = newConfig
            let specials = newConfig.activeRuleLabels.filter { $0 != "ループ" }
            diceMessage = specials.isEmpty ? "🎲 クラシックルールになりました" : "🎲 " + specials.joined(separator: "・") + " がON"
        }
        diceToken += 1
        HapticManager.split()
        SoundManager.shared.play(.split)
    }
}
