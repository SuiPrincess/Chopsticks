import AVFoundation
import Foundation

/// ゲーム内効果音。音源ファイルを持たず、起動時に短い波形を合成してメモリに置く。
/// `.ambient`カテゴリなのでマナーモードを尊重し、他アプリの音楽を止めない。
enum SoundEffect: CaseIterable {
    case button
    case select
    case tap
    case split
    case breakHand
    case poison
    case bomb
    case turnWarning
    case win
    case lose
    case draw
    case rankUp
    case levelUp
    case achievement
}

@MainActor
final class SoundManager {
    static let shared = SoundManager()

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayerIndex = 0
    private var buffers: [SoundEffect: AVAudioPCMBuffer] = [:]
    private let sampleRate: Double = 44_100
    private lazy var format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    private var isPrepared = false
    private var isEnabledProvider: () -> Bool = { true }

    private init() {}

    /// 起動時に一度呼ぶ。波形の合成とエンジンの準備を行う（数十ms）。
    func prepare(isEnabled: @escaping () -> Bool) {
        isEnabledProvider = isEnabled
        guard !isPrepared else { return }
        isPrepared = true

        let session = AVAudioSession.sharedInstance()
        // .ambient はマナーモードを尊重し、他アプリの音楽と重ねて再生できる
        try? session.setCategory(.ambient, mode: .default)

        for _ in 0..<4 {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            players.append(node)
        }
        engine.mainMixerNode.outputVolume = 0.9

        for effect in SoundEffect.allCases {
            buffers[effect] = Synth.render(effect, sampleRate: sampleRate, format: format)
        }
        engine.prepare()
        // 最初の効果音で起動の待ちが出ないよう、先にエンジンを動かしておく
        try? session.setActive(true)
        try? engine.start()

        // イヤホンの抜き差しなどでエンジンが止まったら、次の再生時に起動し直す
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.engineNeedsRestart = true }
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] _ in
            // 割り込み（電話など）後はエンジンが止まるので、次の再生時に再起動する
            MainActor.assumeIsolated { self?.engineNeedsRestart = true }
        }
    }

    private var engineNeedsRestart = false

    func play(_ effect: SoundEffect) {
        guard isPrepared, isEnabledProvider(), let buffer = buffers[effect] else { return }
        if !engine.isRunning || engineNeedsRestart {
            engineNeedsRestart = false
            try? AVAudioSession.sharedInstance().setActive(true, options: [])
            do { try engine.start() } catch { return }
        }
        let player = players[nextPlayerIndex]
        nextPlayerIndex = (nextPlayerIndex + 1) % players.count
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: [.interrupts], completionHandler: nil)
        player.play()
    }
}

// MARK: - 波形合成

private enum Synth {
    struct Note {
        var frequency: Double
        var start: Double
        var duration: Double
        var amplitude: Double = 0.3
        var wave: Wave = .sine
        var attack: Double = 0.005
        var release: Double = 0.08
        /// 終了周波数（ピッチスイープ）。nilなら一定。
        var endFrequency: Double? = nil
    }

    enum Wave { case sine, triangle, square, noise }

    static func render(_ effect: SoundEffect, sampleRate: Double, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let notes = notes(for: effect)
        let total = (notes.map { $0.start + $0.duration }.max() ?? 0.1) + 0.05
        let frameCount = AVAudioFrameCount(total * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = frameCount

        var rng = SeededGenerator(seed: 42)
        var phases = [Double](repeating: 0, count: notes.count)
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            var sample = 0.0
            for (n, note) in notes.enumerated() {
                let local = t - note.start
                guard local >= 0, local < note.duration else { continue }
                let env = envelope(local, duration: note.duration, attack: note.attack, release: note.release)
                let freq: Double
                if let end = note.endFrequency {
                    freq = note.frequency + (end - note.frequency) * (local / note.duration)
                } else {
                    freq = note.frequency
                }
                phases[n] += freq / sampleRate
                let phase = phases[n] - floor(phases[n])
                let value: Double
                switch note.wave {
                case .sine: value = sin(phase * 2 * .pi)
                case .triangle: value = 4 * abs(phase - 0.5) - 1
                case .square: value = phase < 0.5 ? 1 : -1
                case .noise: value = Double(rng.next() % 20_001) / 10_000 - 1
                }
                sample += value * env * note.amplitude
            }
            channel[i] = Float(max(-1, min(1, sample)))
        }
        return buffer
    }

    private static func envelope(_ t: Double, duration: Double, attack: Double, release: Double) -> Double {
        if t < attack { return t / attack }
        let releaseStart = max(attack, duration - release)
        if t > releaseStart { return max(0, 1 - (t - releaseStart) / release) }
        return 1
    }

    private static func notes(for effect: SoundEffect) -> [Note] {
        switch effect {
        case .button:
            return [Note(frequency: 1800, start: 0, duration: 0.03, amplitude: 0.12, wave: .triangle, attack: 0.002, release: 0.02)]
        case .select:
            return [
                Note(frequency: 660, start: 0, duration: 0.06, amplitude: 0.22, wave: .triangle, release: 0.03),
                Note(frequency: 990, start: 0.05, duration: 0.09, amplitude: 0.22, wave: .triangle, release: 0.06),
            ]
        case .tap:
            return [
                Note(frequency: 520, start: 0, duration: 0.09, amplitude: 0.3, wave: .triangle, release: 0.07, endFrequency: 380),
                Note(frequency: 0, start: 0, duration: 0.03, amplitude: 0.08, wave: .noise, attack: 0.001, release: 0.025),
            ]
        case .split:
            return [Note(frequency: 400, start: 0, duration: 0.16, amplitude: 0.2, wave: .sine, release: 0.08, endFrequency: 820)]
        case .breakHand:
            return [
                Note(frequency: 0, start: 0, duration: 0.18, amplitude: 0.35, wave: .noise, attack: 0.001, release: 0.16),
                Note(frequency: 120, start: 0, duration: 0.22, amplitude: 0.4, wave: .sine, release: 0.2, endFrequency: 50),
            ]
        case .poison:
            return [
                Note(frequency: 620, start: 0, duration: 0.3, amplitude: 0.22, wave: .square, release: 0.2, endFrequency: 180),
                Note(frequency: 0, start: 0.1, duration: 0.2, amplitude: 0.1, wave: .noise, release: 0.18),
            ]
        case .bomb:
            return [
                Note(frequency: 0, start: 0, duration: 0.45, amplitude: 0.4, wave: .noise, attack: 0.001, release: 0.4),
                Note(frequency: 70, start: 0, duration: 0.5, amplitude: 0.5, wave: .sine, release: 0.45, endFrequency: 30),
            ]
        case .turnWarning:
            return [
                Note(frequency: 880, start: 0, duration: 0.08, amplitude: 0.2, wave: .square, release: 0.04),
                Note(frequency: 880, start: 0.14, duration: 0.08, amplitude: 0.2, wave: .square, release: 0.04),
            ]
        case .win:
            return arpeggio([523.25, 659.25, 783.99, 1046.5], step: 0.11, duration: 0.3, amplitude: 0.26)
        case .lose:
            return [
                Note(frequency: 329.63, start: 0, duration: 0.25, amplitude: 0.22, wave: .triangle, release: 0.1),
                Note(frequency: 261.63, start: 0.22, duration: 0.5, amplitude: 0.22, wave: .triangle, release: 0.35, endFrequency: 220),
            ]
        case .draw:
            return [Note(frequency: 440, start: 0, duration: 0.35, amplitude: 0.2, wave: .triangle, release: 0.25)]
        case .rankUp:
            return arpeggio([783.99, 1046.5, 1318.5, 1568], step: 0.13, duration: 0.6, amplitude: 0.26)
                + [Note(frequency: 392, start: 0, duration: 0.9, amplitude: 0.12, wave: .sine, release: 0.5)]
        case .levelUp:
            return arpeggio([523.25, 587.33, 659.25, 783.99, 1046.5], step: 0.09, duration: 0.45, amplitude: 0.22)
        case .achievement:
            return arpeggio([1318.5, 1760, 2093, 2637], step: 0.07, duration: 0.35, amplitude: 0.16)
        }
    }

    private static func arpeggio(_ frequencies: [Double], step: Double, duration: Double, amplitude: Double) -> [Note] {
        frequencies.enumerated().map { i, f in
            let isLast = i == frequencies.count - 1
            return Note(
                frequency: f,
                start: Double(i) * step,
                duration: isLast ? duration : step + 0.05,
                amplitude: amplitude,
                wave: .triangle,
                release: isLast ? duration * 0.6 : 0.04
            )
        }
    }
}
