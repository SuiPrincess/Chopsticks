import SwiftUI
import StoreKit

/// ショップ: プレミアム（全テーマ＋ヒント無制限）と投げ銭
struct ShopView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = StoreManager.shared
    @State private var themeStore = ThemeStore.shared

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.bgDark.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        premiumCard

                        themeSection

                        tipSection

                        Button {
                            Task { await store.restorePurchases() }
                        } label: {
                            Text("購入を復元")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .padding(.top, 4)

                        Text("プレミアムは買い切りです。価格は購入画面に表示されます。")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.white.opacity(0.3))
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("ショップ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .alert("応援ありがとうございます！🙌", isPresented: Binding(
                get: { store.showTipThanks },
                set: { store.showTipThanks = $0 }
            )) {
                Button("どういたしまして") {}
            } message: {
                Text("いただいた応援は開発の励みになります。これからもChopsticksをよろしくお願いします！")
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await store.refresh()
        }
    }

    // MARK: - Premium

    @ViewBuilder
    private var premiumCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .foregroundStyle(AppTheme.goldGradient)
                Text("プレミアム")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                if store.isPremium {
                    Text("解放済み")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(AppTheme.goldGradient))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                premiumFeature("paintpalette.fill", "全カラーテーマを解放（5種類）")
                premiumFeature("lightbulb.fill", "AIヒントが無制限に")
                premiumFeature("heart.fill", "個人開発の応援になります")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if store.isPremium {
                Label("いつも応援ありがとうございます！", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.goldGradient)
                    .padding(.top, 2)
            } else if let premium = store.premiumProduct {
                Button {
                    Task { await store.purchase(premium) }
                } label: {
                    HStack(spacing: 8) {
                        if store.purchaseInProgress {
                            ProgressView().tint(.white)
                        }
                        Text("\(premium.displayPrice) で解放する")
                    }
                }
                .buttonStyle(GlassButtonStyle(color: .yellow))
                .disabled(store.purchaseInProgress)
            } else if store.isLoadingProducts {
                ProgressView().tint(.white.opacity(0.6))
                    .padding(.vertical, 8)
            } else {
                Text("ストアに接続できませんでした。時間をおいて再度お試しください。")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [.yellow.opacity(0.6), .orange.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    @ViewBuilder
    private func premiumFeature(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    // MARK: - Themes

    @ViewBuilder
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("カラーテーマ")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.accent.opacity(0.8))
                .tracking(1)
                .textCase(.uppercase)

            ForEach(Theme.all) { theme in
                themeRow(theme)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.glassBorder, lineWidth: 0.5)
                )
        )
    }

    @ViewBuilder
    private func themeRow(_ theme: Theme) -> some View {
        let isSelected = themeStore.selectedThemeID == theme.id
        let isLocked = theme.isPremium && !store.isPremium

        Button {
            if isLocked {
                HapticManager.handTap()
            } else {
                themeStore.select(theme, isPremiumUnlocked: store.isPremium)
                HapticManager.handSelect()
            }
        } label: {
            HStack(spacing: 12) {
                // カラープレビュー
                HStack(spacing: 4) {
                    Capsule().fill(theme.player1).frame(width: 8, height: 24)
                    Capsule().fill(theme.player2).frame(width: 8, height: 24)
                    Capsule().fill(theme.accentSecondary).frame(width: 8, height: 24)
                }
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 8).fill(theme.bgMid)
                )

                Text(theme.name)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.yellow.opacity(0.7))
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppTheme.accent.opacity(0.1) : .clear)
            )
            .opacity(isLocked ? 0.65 : 1)
        }
    }

    // MARK: - Tips

    @ViewBuilder
    private var tipSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("開発者に差し入れ")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.accent.opacity(0.8))
                .tracking(1)
                .textCase(.uppercase)

            if store.tipProducts.isEmpty {
                Text(store.isLoadingProducts ? "読み込み中..." : "現在利用できません")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            } else {
                HStack(spacing: 12) {
                    ForEach(store.tipProducts, id: \.id) { product in
                        Button {
                            Task { await store.purchase(product) }
                        } label: {
                            VStack(spacing: 4) {
                                Text(product.id == StoreManager.tipLargeID ? "🍱" : "🍙")
                                    .font(.system(size: 24))
                                Text(product.displayPrice)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(AppTheme.glassBorder, lineWidth: 0.5)
                                    )
                            )
                        }
                        .disabled(store.purchaseInProgress)
                    }
                }
            }
        }
        .padding(16)
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
