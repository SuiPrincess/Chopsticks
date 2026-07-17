import Foundation
import Observation
import StoreKit

/// StoreKit 2による課金管理。
/// - プレミアム（買い切り）: 全テーマ解放＋ヒント無制限
/// - 投げ銭（消耗型）: 開発の応援
/// App Store Connect未設定の間は商品が空になるだけで、他機能に影響しない。
@Observable
@MainActor
final class StoreManager {
    static let shared = StoreManager()

    // MARK: - Product IDs
    static let premiumID = "com.suiprincess.chopsticks.premium"
    static let tipSmallID = "com.suiprincess.chopsticks.tip.small"
    static let tipLargeID = "com.suiprincess.chopsticks.tip.large"
    static let allProductIDs: Set<String> = [premiumID, tipSmallID, tipLargeID]

    // MARK: - State
    private(set) var products: [Product] = []
    private(set) var isLoadingProducts = false
    private(set) var purchaseInProgress = false
    /// プレミアム解放済みか。オフライン起動用にUserDefaultsへミラーする。
    private(set) var isPremium: Bool
    /// 投げ銭のお礼表示用
    var showTipThanks = false
    /// 購入処理がエラーで開始できなかった（ネットワーク等）
    var showPurchaseError = false

    private static let premiumKey = "store.premiumUnlocked"
    private var transactionListener: Task<Void, Never>?

    private init() {
        isPremium = UserDefaults.standard.bool(forKey: Self.premiumKey)
        transactionListener = Task { await self.listenForTransactionUpdates() }
        Task { await self.refresh() }
    }

    var premiumProduct: Product? {
        products.first { $0.id == Self.premiumID }
    }

    var tipProducts: [Product] {
        products
            .filter { $0.id == Self.tipSmallID || $0.id == Self.tipLargeID }
            .sorted { $0.price < $1.price }
    }

    // MARK: - Loading

    func refresh() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        let loaded = (try? await Product.products(for: Self.allProductIDs)) ?? []
        if !loaded.isEmpty {
            products = loaded.sorted { $0.price < $1.price }
        }
        await updateEntitlements()
    }

    /// 現在の権利からプレミアム状態を再計算する
    func updateEntitlements() async {
        var hasPremium = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.premiumID,
               transaction.revocationDate == nil {
                hasPremium = true
            }
        }
        // 権利が見つかった時だけ昇格。降格（返金）はTransaction.updatesの
        // revocationDateで処理する（オフライン時の誤降格を避けるため）。
        if hasPremium {
            setPremium(true)
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        guard !purchaseInProgress else { return }
        purchaseInProgress = true
        defer { purchaseInProgress = false }

        let purchaseResult = try? await product.purchase()
        guard let result = purchaseResult else {
            showPurchaseError = true
            return
        }
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { return }
            apply(transaction)
            await transaction.finish()
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    /// 「購入を復元」ボタン用
    func restorePurchases() async {
        try? await AppStore.sync()
        await updateEntitlements()
    }

    // MARK: - Private

    private func listenForTransactionUpdates() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            apply(transaction)
            await transaction.finish()
        }
    }

    private func apply(_ transaction: StoreKit.Transaction) {
        switch transaction.productID {
        case Self.premiumID:
            setPremium(transaction.revocationDate == nil)
        case Self.tipSmallID, Self.tipLargeID:
            if transaction.revocationDate == nil {
                showTipThanks = true
            }
        default:
            break
        }
    }

    private func setPremium(_ value: Bool) {
        isPremium = value
        UserDefaults.standard.set(value, forKey: Self.premiumKey)
    }
}
