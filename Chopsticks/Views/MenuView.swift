import SwiftUI

struct MenuView: View {
    @State private var config = GameConfig()
    @State private var showRuleSettings = false
    @State private var showRuleConfirmation = false
    @State private var showAIDifficultyPicker = false
    @State private var navigateToGame = false
    @State private var titleGlow: CGFloat = 0.3

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
                        Button {
                            config.gameMode = .localTwoPlayer
                            showRuleConfirmation = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "person.2.fill")
                                Text("2人対戦")
                            }
                        }
                        .buttonStyle(GlassButtonStyle())

                        // VS AI
                        Button {
                            config.gameMode = .vsAI
                            showAIDifficultyPicker = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "cpu")
                                Text("CPU対戦")
                            }
                        }
                        .buttonStyle(GlassButtonStyle(color: AppTheme.accentSecondary))

                        // Rules
                        Button {
                            showRuleSettings = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "gearshape")
                                Text("ルール設定")
                            }
                        }
                        .buttonStyle(GlassButtonStyle(isPrimary: false))

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
            .sheet(isPresented: $showAIDifficultyPicker) {
                AIDifficultyPickerView(
                    difficulty: $config.aiDifficulty,
                    onStart: {
                        showAIDifficultyPicker = false
                        showRuleConfirmation = true
                    }
                )
                .presentationDetents([.medium])
            }
            .fullScreenCover(isPresented: $showRuleConfirmation) {
                RuleDisplayView(
                    config: config,
                    isPreGame: true,
                    onStart: {
                        showRuleConfirmation = false
                        navigateToGame = true
                    },
                    onDismiss: { showRuleConfirmation = false }
                )
            }
        }
        .onAppear {
            withAnimation(Anim.glowPulse) { titleGlow = 0.8 }
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
