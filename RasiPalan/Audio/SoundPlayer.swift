import AppKit
import AVFoundation

/// Plays the paper sounds. One-shots pick a random variant ("rip" → rip-1/2/3.wav) at a slightly
/// random pitch, so repeated actions never sound identical. The tearing texture is a loop whose
/// volume follows how fast the sheet is being torn.
///
/// AVAudioEngine can block for seconds when the output device stops responding (seen with
/// audio-routing drivers after sleep), so every engine call runs on a queue of its own and the
/// pad never waits on it. While that queue is stuck, new sounds are dropped rather than piling up.
@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()

    var isEnabled = true {
        didSet { if !isEnabled { stopTearing() } }
    }

    private let graph = AudioGraph()
    private let queue = DispatchQueue(label: "RasiPalan.audio", qos: .userInteractive)
    /// Engine calls sent to `queue` and not yet finished.
    private var inFlight = 0
    /// More than this many waiting means the queue is stuck: skip the sound.
    private static let maxInFlight = 4

    private init() {
        let center = NotificationCenter.default
        // The output changed (or went away): the engine has stopped itself; start it afresh next time.
        center.addObserver(forName: .AVAudioEngineConfigurationChange, object: graph.engine, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.restartEngine() }
        }
        // An output device can come back from sleep unresponsive; start fresh rather than wait on it.
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.restartEngine() }
        }
    }

    /// Runs `work` on the audio queue, or not at all if the queue is stuck. Stopping things is
    /// never skipped, so nothing keeps playing once the output comes back.
    private func perform(always: Bool = false, _ work: @escaping @Sendable (AudioGraph) -> Void) {
        guard always || inFlight < Self.maxInFlight else { return }
        inFlight += 1
        queue.async { [graph] in
            work(graph)
            DispatchQueue.main.async { MainActor.assumeIsolated { SoundPlayer.shared.inFlight -= 1 } }
        }
    }

    private func restartEngine() {
        perform(always: true) { $0.stopEngine() }
    }

    /// Plays a random variant of `name` with ±`pitchJitter` speed variation.
    func play(_ name: String, volume: Float = 1, pitchJitter: Float = 0.08) {
        guard isEnabled else { return }
        let rate = 1 + Float.random(in: -pitchJitter...pitchJitter)
        perform { $0.play(name, volume: volume, rate: rate) }
    }

    // MARK: - Continuous tearing

    private var tearing = false
    private var tearVolume: Float = 0
    private var tearTarget: Float = 0
    private var tearTimer: Timer?

    func startTearing() {
        guard isEnabled, !tearing else { return }
        tearing = true
        tearVolume = 0
        tearTarget = 0
        perform { $0.startTearLoop() }
        // Glide the volume towards the target and let it die away when the hand stops,
        // instead of jumping on every mouse event (which crackles).
        tearTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.glideTearVolume() }
        }
    }

    private func glideTearVolume() {
        tearVolume += (tearTarget - tearVolume) * 0.25
        tearTarget *= 0.88
        let volume = tearVolume
        perform { $0.tearPlayer.volume = volume }
    }

    /// Nudges the tearing sound up: 0 = silent … 1 = tearing fast. It fades by itself.
    func setTearIntensity(_ intensity: Double) {
        tearTarget = max(tearTarget, Float(min(max(intensity, 0), 1)) * 0.9)
    }

    func stopTearing() {
        tearTimer?.invalidate()
        tearTimer = nil
        guard tearing else { return }
        tearing = false
        perform(always: true) { $0.tearPlayer.stop() }
    }
}

/// The engine, its players and the decoded sounds. Only ever touched on `SoundPlayer`'s queue.
private final class AudioGraph: @unchecked Sendable {
    let engine = AVAudioEngine()
    let tearPlayer = AVAudioPlayerNode()
    private var voices: [(player: AVAudioPlayerNode, varispeed: AVAudioUnitVarispeed)] = []
    private var nextVoice = 0
    private var buffers: [String: [AVAudioPCMBuffer]] = [:]

    init() {
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

    /// Asks the engine itself rather than remembering, since it stops on its own when the output changes.
    private func startEngineIfNeeded() -> Bool {
        guard !engine.isRunning else { return true }
        do {
            try engine.start()
        } catch {
            NSLog("RasiPalan: audio engine failed: \(error)")
        }
        return engine.isRunning
    }

    func stopEngine() { engine.stop() }

    func play(_ name: String, volume: Float, rate: Float) {
        guard let buffer = buffers[name]?.randomElement(), startEngineIfNeeded() else { return }
        let voice = voices[nextVoice]
        nextVoice = (nextVoice + 1) % voices.count
        voice.player.stop()
        voice.varispeed.rate = rate
        voice.player.volume = volume
        voice.player.scheduleBuffer(buffer)
        voice.player.play()
    }

    func startTearLoop() {
        guard let buffer = buffers["tear-loop"]?.first, startEngineIfNeeded() else { return }
        tearPlayer.volume = 0
        tearPlayer.stop()
        tearPlayer.scheduleBuffer(buffer, at: nil, options: .loops)
        tearPlayer.play()
    }
}
