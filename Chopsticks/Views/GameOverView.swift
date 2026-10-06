import SwiftUI
import StoreKit

struct GameOverView: View {
    let viewModel: GameViewModel
    let onDismiss: () -> Void

    @State private var appeared = false
    @State private var showNotificationOffer = false
    @State private var settings = AppSettings.shared
    @Environment(\.requestReview) private var requestReview
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private var reducesMotion: Bool { systemReduceMotion || settings.reducesEffects }

    // MARK: - 勝敗

    private enum Result { case win, loss, draw, neutral }

    /// 自分から見た結果。1台2人対戦（勝者はいるが「自分」がいない）はneutral。
    private var result: Result {
        if viewModel.isDraw { return .draw }
        guard let won = viewModel.didLocalPlayerWin else { return .neutral }
        return won ? .win : .loss
    }

    private var celebrates: Bool { result == .win || result == .neutral }
    private var turnsPlayed: Int { viewModel.lastSummary?.turnCount ?? viewModel.state.turnCount }
    private var summary: GameSummary? { viewModel.lastSummary }
    private var rewards: GameRewards? { viewModel.rewards }

    var body: some View {
        ZStack {
            Color.black.opacity(0.78)
                .ignoresSafeArea()

            if celebrates && !reducesMotion {
                ConfettiView()
            }

            ScrollView {
                VStack(spacing: 22) {
                    header
                    detailSection
                    footerActions
                }
                .padding(.vertical, 40)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        // 背後の盤面や「やめる」ボタンにVoiceOverが届かないようにする
        .accessibilityAddTraits(.isModal)
        .onAppear {
            withAnimation(Anim.gameOver) { appeared = true }
        }
        .task {
            await handlePostGameOffers()
        }
        // リマッチ要求を受信
        .alert(
            "リマッチしますか？",
            isPresented: Binding(
                get: { viewModel.showRematchRequest },
                set: { viewModel.showRematchRequest = $0 }
            )
        ) {
            Button("リマッチする") { viewModel.acceptRematch() }
            Button("やめる", role: .cancel) {
                viewModel.declineRematch()
                viewModel.leaveMultiplayer()
                onDismiss()
            }
        } message: {
            Text("相手がもう一戦を申し込んでいます")
        }
    }

    // MARK: - ヘッダー

    private var header: some View {
        VStack(spacing: 14) {
            icon

            VStack(spacing: 8) {
                Text(titleText)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(celebrates ? Color.white : Color.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)

                Text(subtitleText)
                    .font(.system(.callout, design: .rounded, weight: .heavy))
                    .foregroundStyle(celebrates
                        ? AnyShapeStyle(AppTheme.accentGradient)
                        : AnyShapeStyle(Color.white.opacity(0.5)))
                    .multilineTextAlignment(.center)

                if let summary, summary.isWin {
                    if summary.isPerfect {
                        Text("💯 パーフェクト！ 一本も失わずに勝利")
                            .badgeStyle(AppTheme.goldGradient)
                    }
                    if summary.isComeback {
                        Text("🔥 大逆転！")
                            .badgeStyle(AppTheme.goldGradient)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var icon: some View {
        switch result {
        case .draw:
            Image(systemName: "equal.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.4))
        case .loss:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.3))
        case .win, .neutral:
            Image(systemName: "trophy.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.goldGradient)
                .shadow(color: .yellow.opacity(0.5), radius: 16)
        }
    }

    private var titleText: String {
        switch result {
        case .win: "あなたの勝ち！"
        case .loss: "まけた…"
        case .draw: "引き分け"
        case .neutral: "\(viewModel.winnerName ?? "")の勝ち！"
        }
    }

    private var subtitleText: String {
        switch result {
        case .win: "おめでとう！ \(turnsPlayed)ターンで決着"
        case .loss: lossMessage
        case .draw: "同点でした（\(turnsPlayed)ターン）"
        case .neutral: "\(turnsPlayed)ターンで決着"
        }
    }

    private var lossMessage: String {
        if viewModel.isMultiplayer { return "\(viewModel.winnerName ?? "相手")の勝ちです" }
        return GameStats.shared.mercyBoost > 0 ? "CPUがちょっと油断しているかも…もう一回！" : "もう一回挑戦しよう"
    }

    // MARK: - 詳細（XP・ランク・実績など）

    @ViewBuilder
    private var detailSection: some View {
        VStack(spacing: 14) {
            if let rewards {
                rewardCard(rewards)
            }

            if viewModel.config.isRanked && !GameStats.shared.isRankMaxed {
                let stats = GameStats.shared
                RankLadderView(level: stats.rankLevel, stars: stats.rankStars, starsRequired: stats.starsRequiredForCurrentLevel)
                    .padding(.horizontal, 24)
            }

            if viewModel.isVsAI {
                statsLines
            }

            if !viewModel.unlockedAchievements.isEmpty {
                achievementsRow
            }

            if result == .loss && !viewModel.isMultiplayer {
                Text("💡 \(tipText)")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if viewModel.isMultiplayer || !(viewModel.isVsAI) {
                scoreLine
            }
        }
    }

    private func rewardCard(_ rewards: GameRewards) -> some View {
        let stats = GameStats.shared
        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text("+\(rewards.xpGained) XP")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(AppTheme.accent)
                Spacer()
                Text("Lv.\(stats.playerLevel) \(stats.playerTitle)")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            ProgressView(value: stats.levelProgress)
                .tint(AppTheme.accent)

            if rewards.leveledUp {
                Text("🎉 レベルアップ！ Lv.\(stats.playerLevel)" + (rewards.newTitle.map { "  称号「\($0)」" } ?? ""))
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(.yellow)
            }
            if rewards.rankedUp {
                Text("⬆️ ランクUP！ 次は Lv.\(stats.rankLevel)")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(.orange)
            }
            if rewards.maxLevelWin {
                Text("👑 Lv.MAX 通算\(stats.maxLevelWins)勝")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(.orange)
            }
            if rewards.dailyChallengeCleared {
                Text("🗓 デイリーチャレンジ クリア！ +\(DailyChallenge.bonusXP)XP")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(.cyan)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.glassBorder, lineWidth: 0.5))
        )
        .padding(.horizontal, 28)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statsLines: some View {
        let stats = GameStats.shared
        VStack(spacing: 6) {
            if stats.currentStreak >= 2 {
                Text("🔥 \(stats.currentStreak)連勝中！")
                    .font(.system(.callout, design: .rounded, weight: .bold))
                    .foregroundStyle(.orange)
            }
            // didSetNewRecordは勝敗記録時のみ更新されるため、引き分けでは前ゲームの値を表示しない
            if rewards?.newStreakRecord == true && result != .draw {
                Text("✨ 自己ベスト更新！")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.yellow)
            }
            Text("通算 \(stats.wins)勝 \(stats.losses)敗 ・ ベスト連勝 \(stats.bestStreak)")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    private var achievementsRow: some View {
        VStack(spacing: 8) {
            Text("🏅 実績を解除！")
                .font(.system(.footnote, design: .rounded, weight: .heavy))
                .foregroundStyle(.yellow)
            FlowLayout(spacing: 8, rowSpacing: 8) {
                ForEach(viewModel.unlockedAchievements) { achievement in
                    Label(achievement.title, systemImage: achievement.symbol)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.yellow.opacity(0.16)))
                        .overlay(Capsule().stroke(Color.yellow.opacity(0.4), lineWidth: 0.5))
                }
            }
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var scoreLine: some View {
        let score = viewModel.sessionScore
        if score.player1 + score.player2 >= 1 {
            let bottomIsPlayer1 = viewModel.bottomPlayer.id == viewModel.state.player1.id
            let mine = bottomIsPlayer1 ? score.player1 : score.player2
            let theirs = bottomIsPlayer1 ? score.player2 : score.player1
            Text("連戦スコア  \(viewModel.bottomPlayer.name) \(mine) - \(theirs) \(viewModel.topPlayer.name)")
                .font(.system(.footnote, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private let tips = [
        "リーチ（赤い手）の相手の手を先に叩くと、攻めのチャンスが広がります",
        "指が4本の手は、相手の1本攻撃で死んでしまいます。早めに数を減らそう",
        "5を超えた分はループします。4+3=7は2になることを覚えておこう",
        "相手が攻撃できる手を減らすのが勝ちへの近道です",
        "迷ったら、相手の手を1本ずつ確実に減らしていこう",
    ]

    private var tipText: String { tips[viewModel.state.turnCount % tips.count] }

    // MARK: - ボタン

    @ViewBuilder
    private var footerActions: some View {
        VStack(spacing: 12) {
            if showNotificationOffer {
                notificationOffer
            }

            if viewModel.isMultiplayer {
                multiplayerButtons
            } else {
                soloButtons
            }
        }
        .padding(.horizontal, 40)
    }

    @ViewBuilder
    private var soloButtons: some View {
        Button(retryLabel) {
            viewModel.newGame()
        }
        .buttonStyle(GlassButtonStyle(color: retryColor))

        Button("メニューへ") {
            onDismiss()
        }
        .buttonStyle(GlassButtonStyle(isPrimary: false))

        if result == .win && viewModel.isVsAI {
            ShareLink(item: shareText) {
                Label("結果を自慢する", systemImage: "square.and.arrow.up")
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                    .frame(minHeight: 44)
            }
        }
    }

    @ViewBuilder
    private var multiplayerButtons: some View {
        if viewModel.isConnectionLost {
            Text("対戦が終了しました")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            Button("メニューへ") {
                viewModel.disconnectMultiplayer()
                onDismiss()
            }
            .buttonStyle(GlassButtonStyle())
        } else if viewModel.isWaitingForRematch {
            HStack(spacing: 8) {
                ProgressView().tint(.white)
                Text("相手の返事を待っています…")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            }
            Button("キャンセル") {
                viewModel.cancelRematchRequest()
            }
            .buttonStyle(GlassButtonStyle(isPrimary: false))
        } else if viewModel.isWaitingForHost {
            HStack(spacing: 8) {
                ProgressView().tint(.white)
                Text("次の対戦を準備しています…")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            }
            Button("メニューへ") {
                viewModel.leaveMultiplayer()
                onDismiss()
            }
            .buttonStyle(GlassButtonStyle(isPrimary: false))
        } else {
            Button("リマッチ") {
                viewModel.requestRematch()
            }
            .buttonStyle(GlassButtonStyle())

            Button("メニューへ") {
                viewModel.leaveMultiplayer()
                onDismiss()
            }
            .buttonStyle(GlassButtonStyle(isPrimary: false))
        }
    }

    private var notificationOffer: some View {
        VStack(spacing: 10) {
            Text("🔔 毎日のチャレンジをお知らせしますか？")
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                Button("お知らせを受け取る") {
                    showNotificationOffer = false
                    Task {
                        if await NotificationManager.shared.requestPermission() {
                            NotificationManager.shared.refreshSchedule(stats: GameStats.shared, settings: AppSettings.shared)
                        }
                    }
                }
                .buttonStyle(GlassButtonStyle())

                Button("あとで") {
                    settings.hasAskedNotificationPermission = true
                    showNotificationOffer = false
                }
                .buttonStyle(GlassButtonStyle(isPrimary: false))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.accent.opacity(0.4), lineWidth: 0.8))
        )
    }

    // MARK: - ボタンの文言

    private var retryLabel: String {
        let stats = GameStats.shared
        if viewModel.config.isRanked {
            if result == .loss { return "リベンジ！ Lv.\(stats.rankLevel)" }
            return stats.isRankMaxed ? "もう一戦（Lv.MAX）" : "Lv.\(stats.rankLevel)に挑戦"
        }
        return result == .loss ? "リベンジ！" : "もう一度"
    }

    private var retryColor: Color {
        viewModel.config.isRanked ? .orange : AppTheme.accent
    }

    private var shareText: String {
        let stats = GameStats.shared
        if viewModel.config.isDailyChallenge {
            return "割り箸バトルの今日のチャレンジ「\(stats.todaysChallenge.title)」をクリア！ #割り箸バトル"
        }
        if viewModel.config.isRanked, let level = viewModel.config.aiLevel {
            return "割り箸バトルでCPU Lv.\(level)を撃破！ ランクLv.\(stats.rankLevel) 🔥 #割り箸バトル"
        }
        if stats.currentStreak >= 2 {
            return "割り箸バトルでCPUに\(stats.currentStreak)連勝中！🔥 #割り箸バトル"
        }
        return "割り箸バトルでCPUに勝利！✌️ #割り箸バトル"
    }

    // MARK: - レビュー依頼・通知許可（気分が良い瞬間だけ）

    private func handlePostGameOffers() async {
        guard let rewards, result == .win, viewModel.isVsAI else { return }
        let stats = GameStats.shared
        if NotificationManager.shared.shouldOfferPermission(stats: stats) {
            showNotificationOffer = true
        }
        if stats.shouldRequestReview(after: rewards) {
            // 勝利演出が落ち着いてから出す。画面を離れるとこのタスクごと取り消される。
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            stats.markReviewRequested()
            requestReview()
        }
    }
}

private extension Text {
    func badgeStyle(_ style: LinearGradient) -> some View {
        self
            .font(.system(.subheadline, design: .rounded, weight: .heavy))
            .foregroundStyle(style)
            .multilineTextAlignment(.center)
    }
}
