import Foundation

@MainActor
protocol MultiplayerService: AnyObject {
    var onMessageReceived: ((MultiplayerMessage) -> Void)? { get set }
    var onConnectionChanged: ((Bool) -> Void)? { get set }
    var isHost: Bool { get }
    var opponentName: String { get }
    func send(_ message: MultiplayerMessage)
    func disconnect()
}
