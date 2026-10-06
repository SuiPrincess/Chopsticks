import SwiftUI
import GameKit

/// Game Centerのマッチメイキング画面。閉じる処理はSwiftUI側のバインディングに任せる
/// （ここで`dismiss`まで呼ぶとシートの状態と食い違う）。
struct GameKitMatchmakerView: UIViewControllerRepresentable {
    let onMatchFound: (GKMatch) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        request.inviteMessage = "割り箸バトルで対戦しよう！"

        guard let matchmakerVC = GKMatchmakerViewController(matchRequest: request) else {
            // フォールバック: 空のVCを返す
            let vc = UIViewController()
            DispatchQueue.main.async { onCancel() }
            return vc
        }
        matchmakerVC.matchmakerDelegate = context.coordinator
        return matchmakerVC
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onMatchFound: onMatchFound, onCancel: onCancel)
    }

    final class Coordinator: NSObject, GKMatchmakerViewControllerDelegate {
        let onMatchFound: (GKMatch) -> Void
        let onCancel: () -> Void
        private var didFinish = false

        init(onMatchFound: @escaping (GKMatch) -> Void, onCancel: @escaping () -> Void) {
            self.onMatchFound = onMatchFound
            self.onCancel = onCancel
        }

        func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
            guard !didFinish else { return }
            didFinish = true
            onCancel()
        }

        func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
            guard !didFinish else { return }
            didFinish = true
            onCancel()
        }

        func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
            guard !didFinish else { return }
            didFinish = true
            onMatchFound(match)
        }
    }
}
