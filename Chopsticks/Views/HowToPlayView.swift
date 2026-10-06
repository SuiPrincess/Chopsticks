import SwiftUI

/// 遊び方の説明（初回起動時に自動表示。メニューと設定からいつでも開ける）
struct HowToPlayView: View {
    let onFinish: () -> Void

    @State private var page = 0
    private let pageCount = 5

    var body: some View {
        ZStack {
            AppTheme.bgDark.ignoresSafeArea()
            BackgroundGradientView()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("スキップ", action: onFinish)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(minWidth: 44, minHeight: 44)
                        .padding(.horizontal, 8)
                        .opacity(page < pageCount - 1 ? 1 : 0)
                        .accessibilityHidden(page >= pageCount - 1)
                        .allowsHitTesting(page < pageCount - 1)
                }
                .padding(.horizontal, 12)

                TabView(selection: $page) {
                    pageView(
                        title: "ゴールは「相手の手を全部0にすること」",
                        text: "お互いに指1本ずつの手でスタート。相手の手をぜんぶ倒したら勝ちです。",
                        illustration: goalIllustration
                    )
                    .tag(0)

                    pageView(
                        title: "手をえらんで、相手の手をタップ",
                        text: "自分の手を選んでから、相手の手をタップ。選んだ手の指の数が、叩かれた手に足されます。",
                        illustration: attackIllustration
                    )
                    .tag(1)

                    pageView(
                        title: "5になった手は死んでしまう",
                        text: "ちょうど5本になった手は死亡。5を超えたら余りから数え直します（4+3=7 → 2）。",
                        illustration: deathIllustration
                    )
                    .tag(2)

                    pageView(
                        title: "赤く光る手に注意！",
                        text: "赤い手は、次の攻撃で死んでしまうサイン。守るか、先に相手の手を叩こう。",
                        illustration: dangerIllustration
                    )
                    .tag(3)

                    pageView(
                        title: "強くなって、毎日遊ぼう",
                        text: "ランク戦でCPUを倒してレベルアップ。毎日のチャレンジでボーナス経験値がもらえます。60ターンで決着しないときは、生きている手の数、指の少なさで判定します。",
                        illustration: growthIllustration
                    )
                    .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Button(page < pageCount - 1 ? "つぎへ" : "はじめる") {
                    if page < pageCount - 1 {
                        withAnimation { page += 1 }
                    } else {
                        onFinish()
                    }
                }
                .buttonStyle(GlassButtonStyle())
                .padding(.horizontal, 40)
                .padding(.bottom, 24)
            }
        }
    }

    private func pageView<Illustration: View>(title: String, text: String, illustration: Illustration) -> some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 0)
                    illustration
                        .frame(minHeight: 120)
                    VStack(spacing: 12) {
                        Text(title)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        Text(text)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 32)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                .padding(.bottom, 40)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: - Illustrations

    private var goalIllustration: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                MiniHandCard(count: 0, color: AppTheme.player2Color, isDead: true)
                MiniHandCard(count: 0, color: AppTheme.player2Color, isDead: true)
            }
            Image(systemName: "arrow.up")
                .foregroundStyle(.white.opacity(0.4))
            HStack(spacing: 16) {
                MiniHandCard(count: 1, color: AppTheme.player1Color)
                MiniHandCard(count: 1, color: AppTheme.player1Color)
            }
        }
    }

    private var attackIllustration: some View {
        HStack(spacing: 8) {
            MiniHandCard(count: 2, color: AppTheme.player1Color)
            Image(systemName: "arrow.right")
                .foregroundStyle(.white.opacity(0.5))
            MiniHandCard(count: 1, color: AppTheme.player2Color)
            Image(systemName: "equal")
                .foregroundStyle(.white.opacity(0.5))
            MiniHandCard(count: 3, color: AppTheme.player2Color)
        }
    }

    private var deathIllustration: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                MiniHandCard(count: 3, color: AppTheme.player2Color)
                Text("+2").font(.system(.headline, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                Image(systemName: "equal").foregroundStyle(.white.opacity(0.5))
                MiniHandCard(count: 0, color: AppTheme.player2Color, isDead: true)
            }
            HStack(spacing: 8) {
                MiniHandCard(count: 4, color: AppTheme.player2Color)
                Text("+3").font(.system(.headline, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                Image(systemName: "equal").foregroundStyle(.white.opacity(0.5))
                MiniHandCard(count: 2, color: AppTheme.player2Color)
            }
        }
    }

    private var dangerIllustration: some View {
        HStack(spacing: 20) {
            MiniHandCard(count: 4, color: AppTheme.player1Color, isDanger: true)
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title)
                    .foregroundStyle(.red)
                Text("あと1撃で死亡")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private var growthIllustration: some View {
        HStack(spacing: 28) {
            illustrationBadge(symbol: "trophy.fill", label: "ランク戦", tint: .orange)
            illustrationBadge(symbol: "calendar.badge.checkmark", label: "毎日の\nチャレンジ", tint: .cyan)
            illustrationBadge(symbol: "star.fill", label: "実績", tint: .yellow)
        }
    }

    private func illustrationBadge(symbol: String, label: String, tint: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 28))
                .foregroundStyle(tint)
                .frame(width: 64, height: 64)
                .background(Circle().fill(tint.opacity(0.15)))
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
        }
    }
}
