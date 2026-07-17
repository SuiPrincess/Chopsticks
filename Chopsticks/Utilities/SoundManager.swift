import AVFoundation

/// 効果音の再生。設定でOFFにでき、サイレントスイッチ・他アプリの音楽を尊重する
/// （.ambientカテゴリ）。プレイヤーは初回再生時にまとめてプリロードする。
@MainActor
enum SoundManager {
    enum Effect: String, CaseIterable {
        case tap
        case select
        case split
        case breakHand = "break"
        case boom
        case poison
        case win
        case lose
        case rankup
    }

    private static var players: [Effect: AVAudioPlayer] = [:]
    private static var isPrepared = false

    /// 起動時（メニュー表示時）に呼んでおくと初回再生の遅延がない
    static func prepare() {
        guard !isPrepared else { return }
        isPrepared = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        for effect in Effect.allCases {
            guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav"),
                  let player = try? AVAudioPlayer(contentsOf: url)
            else { continue }
            player.prepareToPlay()
            players[effect] = player
        }
    }

    static func play(_ effect: Effect) {
        guard SettingsStore.shared.isSoundEnabled else { return }
        prepare()
        guard let player = players[effect] else { return }
        if player.isPlaying {
            player.currentTime = 0
        }
        player.play()
    }
}
