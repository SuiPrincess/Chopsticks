import SwiftUI
import GameKit

struct GameKitMatchmakerView: UIViewControllerRepresentable {
    let onMatchFound: (GKMatch) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2

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

        init(onMatchFound: @escaping (GKMatch) -> Void, onCancel: @escaping () -> Void) {
            self.onMatchFound = onMatchFound
            self.onCancel = onCancel
        }

        func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
            viewController.dismiss(animated: true)
            onCancel()
        }

        func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
            viewController.dismiss(animated: true)
            onCancel()
        }

        func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
            viewController.dismiss(animated: true)
            onMatchFound(match)
        }
    }
}
