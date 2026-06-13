import GameKit

@Observable
@MainActor
final class GameCenterManager {
    static let shared = GameCenterManager()

    private(set) var isAuthenticated = false
    private(set) var localPlayerName = ""
    var authenticationError: String?

    private init() {}

    func authenticateLocalPlayer() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.authenticationError = error.localizedDescription
                    self.isAuthenticated = false
                    return
                }
                // viewController != nil means the system wants to show a login UI
                // In SwiftUI this is handled automatically by Game Center
                if viewController == nil {
                    self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                    self.localPlayerName = GKLocalPlayer.local.displayName
                }
            }
        }
    }
}
