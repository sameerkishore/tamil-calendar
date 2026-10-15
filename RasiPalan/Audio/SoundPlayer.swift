import AVFoundation

/// Plays the paper sounds. One-shots pick a random variant ("rip" → rip-1/2/3.wav) at a slightly
/// random pitch, so repeated actions never sound identical. The tearing texture is a loop whose
/// volume follows how fast the sheet is being torn.
@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()

    var isEnabled = true {
        didSet { if !isEnabled { stopTearing() } }
    }

    private let engine = AVAudioEngine()
    private var voices: [(player: AVAudioPlayerNode, varispeed: AVAudioUnitVarispeed)] = []
    private var nextVoice = 0
    private let tearPlayer = AVAudioPlayerNode()
    private var buffers: [String: [AVAudioPCMBuffer]] = [:]
    private var started = false

    private init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        for _ in 0..<8 {
            let player = AVAudioPlayerNode(), varispeed = AVAudioUnitVarispeed()
            engine.attach(player)
            engine.attach(varispeed)
            engine.connect(player, to: varispeed, format: format)
            engine.connect(varispeed, to: engine.mainMixerNode, format: format)
            voices.append((player, varispeed))
        }
        engine.attach(tearPlayer)
        engine.connect(tearPlayer, to: engine.mainMixerNode, format: format)
        loadBuffers()
    }

    private func loadBuffers() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "wav", subdirectory: nil) ?? []
        for url in urls {
            guard let file = try? AVAudioFile(forReading: url),
                  let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
                  (try? file.read(into: buffer)) != nil
            else { continue }
            // "rip-2" → "rip"; "tear-loop" stays "tear-loop".
            let name = url.deletingPathExtension().lastPathComponent
            let base = name.range(of: #"-\d+$"#, options: .regularExpression).map { String(name[..<$0.lowerBound]) } ?? name
            buffers[base, default: []].append(buffer)
        }
    }

    private func startEngineIfNeeded() -> Bool {
        if !started {
            do {
                try engine.start()
                started = true
            } catch {
                NSLog("RasiPalan: audio engine failed: \(error)")
            }
        }
        return started
    }

    /// Plays a random variant of `name` with ±`pitchJitter` speed variation.
    func play(_ name: String, volume: Float = 1, pitchJitter: Float = 0.08) {
        guard isEnabled, let buffer = buffers[name]?.randomElement(), startEngineIfNeeded() else { return }
        let voice = voices[nextVoice]
        nextVoice = (nextVoice + 1) % voices.count
        voice.player.stop()
        voice.varispeed.rate = 1 + Float.random(in: -pitchJitter...pitchJitter)
        voice.player.volume = volume
        voice.player.scheduleBuffer(buffer)
        voice.player.play()
    }

    // MARK: - Continuous tearing

    private var tearTarget: Float = 0
    private var tearTimer: Timer?

    func startTearing() {
        guard isEnabled, !tearPlayer.isPlaying, let buffer = buffers["tear-loop"]?.first, startEngineIfNeeded() else { return }
        tearPlayer.volume = 0
        tearTarget = 0
        tearPlayer.scheduleBuffer(buffer, at: nil, options: .loops)
        tearPlayer.play()
        // Glide the volume towards the target and let it die away when the hand stops,
        // instead of jumping on every mouse event (which crackles).
        tearTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.glideTearVolume() }
        }
    }

    private func glideTearVolume() {
        tearPlayer.volume += (tearTarget - tearPlayer.volume) * 0.25
        tearTarget *= 0.88
    }

    /// Nudges the tearing sound up: 0 = silent … 1 = tearing fast. It fades by itself.
    func setTearIntensity(_ intensity: Double) {
        tearTarget = max(tearTarget, Float(min(max(intensity, 0), 1)) * 0.9)
    }

    func stopTearing() {
        tearTimer?.invalidate()
        tearTimer = nil
        tearPlayer.stop()
    }
}
