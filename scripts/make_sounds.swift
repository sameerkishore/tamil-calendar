// Synthesises the app's paper sounds as WAV files. No recordings, so no licensing.
// Usage: swift scripts/make_sounds.swift RasiPalan/Resources/Sounds
// Replace any file with a real recording of the same name to upgrade it.

import Foundation

let sampleRate = 44_100.0

// MARK: - Tiny DSP kit

struct RNG {
    var state: UInt64
    init(_ seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
    mutating func noise() -> Double { next() * 2 - 1 }
    /// Exponentially distributed, mean 1: many small values, few big ones (like crackles).
    mutating func exp() -> Double { -log(max(next(), 1e-9)) }
}

/// RBJ biquad filter.
struct Biquad {
    var b0 = 0.0, b1 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0
    var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

    static func bandpass(_ f: Double, q: Double) -> Biquad {
        let w = 2 * .pi * f / sampleRate, alpha = sin(w) / (2 * q), a0 = 1 + alpha
        return Biquad(b0: alpha / a0, b1: 0, b2: -alpha / a0, a1: -2 * cos(w) / a0, a2: (1 - alpha) / a0)
    }
    static func lowpass(_ f: Double, q: Double = 0.707) -> Biquad {
        let w = 2 * .pi * f / sampleRate, alpha = sin(w) / (2 * q), a0 = 1 + alpha, c = cos(w)
        return Biquad(b0: (1 - c) / 2 / a0, b1: (1 - c) / a0, b2: (1 - c) / 2 / a0, a1: -2 * c / a0, a2: (1 - alpha) / a0)
    }
    static func highpass(_ f: Double, q: Double = 0.707) -> Biquad {
        let w = 2 * .pi * f / sampleRate, alpha = sin(w) / (2 * q), a0 = 1 + alpha, c = cos(w)
        return Biquad(b0: (1 + c) / 2 / a0, b1: -(1 + c) / a0, b2: (1 + c) / 2 / a0, a1: -2 * c / a0, a2: (1 - alpha) / a0)
    }
    mutating func callAsFunction(_ x: Double) -> Double {
        let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1; x1 = x; y2 = y1; y1 = y
        return y
    }
}

func samples(_ seconds: Double) -> Int { Int(seconds * sampleRate) }

func filter(_ buf: [Double], _ filters: [Biquad]) -> [Double] {
    var fs = filters
    return buf.map { x in
        var v = x
        for i in fs.indices { v = fs[i](v) }
        return v
    }
}

func normalize(_ buf: [Double], peak: Double) -> [Double] {
    let m = buf.map(abs).max() ?? 1
    return m > 0 ? buf.map { $0 / m * peak } : buf
}

/// Paper crackle: a stream of tiny decaying noise bursts. `rate(t)` is crackles per second,
/// `gain(t)` their loudness; together they shape the texture over time.
func crackles(seconds: Double, seed: UInt64, rate: (Double) -> Double, gain: (Double) -> Double,
              burstMs: ClosedRange<Double> = 0.4...3) -> [Double] {
    var rng = RNG(seed)
    var out = [Double](repeating: 0, count: samples(seconds))
    var i = 0
    while i < out.count {
        let t = Double(i) / sampleRate
        let r = max(rate(t), 1)
        i += max(1, Int(rng.exp() / r * sampleRate))
        guard i < out.count else { break }
        let amp = gain(Double(i) / sampleRate) * min(rng.exp(), 4)
        let len = samples((burstMs.lowerBound + rng.next() * (burstMs.upperBound - burstMs.lowerBound)) / 1000)
        for j in 0..<len where i + j < out.count {
            let env = Foundation.exp(-Double(j) / Double(len) * 5)
            out[i + j] += amp * env * rng.noise()
        }
    }
    return out
}

func hiss(seconds: Double, seed: UInt64, envelope: (Double) -> Double) -> [Double] {
    var rng = RNG(seed)
    return (0..<samples(seconds)).map { envelope(Double($0) / sampleRate) * rng.noise() }
}

func mix(_ a: [Double], _ b: [Double], at offset: Int = 0) -> [Double] {
    var out = a
    if out.count < offset + b.count { out += [Double](repeating: 0, count: offset + b.count - out.count) }
    for (i, v) in b.enumerated() { out[offset + i] += v }
    return out
}

func fade(_ buf: [Double], inMs: Double = 3, outMs: Double = 20) -> [Double] {
    let fi = samples(inMs / 1000), fo = samples(outMs / 1000)
    return buf.enumerated().map { i, v in
        var g = 1.0
        if i < fi { g = Double(i) / Double(fi) }
        if i > buf.count - fo { g = min(g, Double(buf.count - i) / Double(fo)) }
        return v * g
    }
}

func tone(_ freq: Double, seconds: Double, decay: Double, amp: Double = 1) -> [Double] {
    (0..<samples(seconds)).map { i in
        let t = Double(i) / sampleRate
        return amp * sin(2 * .pi * freq * t) * exp(-t / decay)
    }
}

func writeWAV(_ buf: [Double], to url: URL) throws {
    var data = Data()
    func append<T: FixedWidthInteger>(_ v: T) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
    let pcm = buf.map { Int16(max(-1, min(1, $0)) * 32_767) }
    data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36 + pcm.count * 2))
    data.append(contentsOf: Array("WAVEfmt ".utf8)); append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
    append(UInt32(sampleRate)); append(UInt32(sampleRate * 2)); append(UInt16(2)); append(UInt16(16))
    data.append(contentsOf: Array("data".utf8)); append(UInt32(pcm.count * 2))
    for s in pcm { append(s) }
    try data.write(to: url)
}

// MARK: - The sounds

let paperBand = { [Biquad.highpass(700), .lowpass(7_500)] }()

/// Continuous tearing texture, looped while the sheet is being torn; volume follows tear speed.
func tearLoop() -> [Double] {
    let seconds = 2.0
    var c = crackles(seconds: seconds, seed: 11, rate: { 500 + 300 * sin($0 * 9) }, gain: { _ in 0.6 })
    c = mix(c, hiss(seconds: seconds, seed: 12) { 0.12 + 0.06 * sin($0 * 23) })
    c = filter(c, paperBand)
    // Seamless loop: crossfade the tail into the head.
    let x = samples(0.08)
    for i in 0..<x {
        let g = Double(i) / Double(x)
        c[i] = c[i] * g + c[c.count - x + i] * (1 - g)
    }
    return normalize(Array(c.dropLast(x)), peak: 0.7)
}

/// The final rip as the sheet comes free: crackles accelerate, then a sharp snap.
func rip(seed: UInt64) -> [Double] {
    let seconds = 0.32
    var c = crackles(seconds: seconds, seed: seed, rate: { 300 + 4_000 * $0 / seconds },
                     gain: { 0.4 + 0.6 * $0 / seconds })
    var snap = hiss(seconds: 0.06, seed: seed + 100) { exp(-$0 / 0.012) * 2.2 }
    snap = filter(snap, [.highpass(1_200)])
    c = mix(c, snap, at: samples(seconds - 0.05))
    return normalize(fade(filter(c, paperBand), outMs: 25), peak: 0.9)
}

/// One perforation giving way: a tiny, crisp paper "tick".
func perforation(seed: UInt64) -> [Double] {
    var rng = RNG(seed)
    let seconds = 0.05 + rng.next() * 0.03
    var click = hiss(seconds: 0.004, seed: seed + 50) { exp(-$0 / 0.0008) * 1.6 }
    click = filter(click, [.highpass(2_500)])
    var c = crackles(seconds: seconds, seed: seed, rate: { _ in 2_500 }, gain: { exp(-$0 / 0.012) }, burstMs: 0.2...1.2)
    c = mix(c, click)
    return normalize(fade(filter(c, [.highpass(1_400), .lowpass(9_000)]), inMs: 0.3, outMs: 8), peak: 0.8)
}

/// Gentle paper settling, for a sheet snapping back onto the pad.
func rustle(seed: UInt64) -> [Double] {
    let seconds = 0.35
    var c = crackles(seconds: seconds, seed: seed, rate: { _ in 120 }, gain: { exp(-$0 / 0.12) * 0.5 })
    c = mix(c, hiss(seconds: seconds, seed: seed + 1) { exp(-$0 / 0.1) * 0.25 })
    return normalize(fade(filter(c, [.highpass(500), .lowpass(4_500)])), peak: 0.35)
}

/// Crumpling a sheet into a ball: irregular bursts of loud crackle.
func crumple(seed: UInt64) -> [Double] {
    let seconds = 0.9
    var rng = RNG(seed)
    let bursts = (0..<5).map { _ in (rng.next() * 0.75, 0.05 + rng.next() * 0.12, 0.5 + rng.next() * 0.5) }
    let gain: (Double) -> Double = { t in
        0.15 + bursts.reduce(0) { acc, b in acc + b.2 * exp(-pow((t - b.0) / b.1, 2)) }
    }
    let c = crackles(seconds: seconds, seed: seed + 7, rate: { 600 + 1_400 * gain($0) }, gain: gain, burstMs: 0.3...4)
    return normalize(fade(filter(c, [.highpass(500), .lowpass(9_000)]), outMs: 60), peak: 0.9)
}

/// A paper ball flying through the air.
func whoosh() -> [Double] {
    let seconds = 0.45
    var rng = RNG(5)
    var bp = Biquad.bandpass(500, q: 1.2)
    let out = (0..<samples(seconds)).map { i -> Double in
        let t = Double(i) / seconds / sampleRate
        if i % 64 == 0 { bp = { var n = Biquad.bandpass(400 + 1_400 * t, q: 1.2); n.x1 = bp.x1; n.x2 = bp.x2; n.y1 = bp.y1; n.y2 = bp.y2; return n }() }
        return bp(rng.noise()) * sin(.pi * t) * sin(.pi * t)
    }
    return normalize(out, peak: 0.45)
}

/// Ball landing in a wire waste-paper basket.
func thunk(seed: UInt64) -> [Double] {
    var c = tone(110 + Double(seed % 3) * 15, seconds: 0.3, decay: 0.05, amp: 0.8)
    c = mix(c, filter(hiss(seconds: 0.12, seed: seed) { exp(-$0 / 0.02) }, [.lowpass(1_800)]))
    let crinkle = filter(crackles(seconds: 0.25, seed: seed + 3, rate: { _ in 300 }, gain: { exp(-$0 / 0.06) * 0.5 }), paperBand)
    c = mix(c, crinkle, at: samples(0.01))
    // Faint wire rattle.
    for f in [1_870.0, 2_630.0] { c = mix(c, tone(f, seconds: 0.3, decay: 0.07, amp: 0.05)) }
    return normalize(fade(c, outMs: 30), peak: 0.85)
}

/// Ball hitting the rim and bouncing off.
func rim() -> [Double] {
    var c = [Double](repeating: 0, count: samples(0.35))
    for (f, a, d) in [(1_240.0, 0.5, 0.09), (2_910.0, 0.3, 0.05), (4_350.0, 0.2, 0.03), (6_020.0, 0.1, 0.02)] {
        c = mix(c, tone(f, seconds: 0.35, decay: d, amp: a))
    }
    c = mix(c, filter(hiss(seconds: 0.02, seed: 9) { exp(-$0 / 0.003) }, [.highpass(2_000)]))
    return normalize(fade(c, outMs: 40), peak: 0.6)
}

/// Tipping the bin out: a tumble of balls, thuds and rustle.
func emptyBin() -> [Double] {
    var c = [Double](repeating: 0, count: samples(1.5))
    var rng = RNG(77)
    for k in 0..<9 {
        let at = samples(0.1 + Double(k) * 0.12 + rng.next() * 0.06)
        c = mix(c, thunk(seed: UInt64(20 + k)).map { $0 * (0.35 + rng.next() * 0.3) }, at: at)
    }
    c = mix(c, crackles(seconds: 1.3, seed: 31, rate: { _ in 400 }, gain: { 0.3 * sin(.pi * $0 / 1.3) }))
    // Metallic bin scrape as it tips.
    c = mix(c, tone(820, seconds: 0.6, decay: 0.25, amp: 0.08))
    return normalize(fade(c, outMs: 120), peak: 0.85)
}

// MARK: - Write

let dir = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "RasiPalan/Resources/Sounds")
try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

var sounds: [(String, [Double])] = [("tear-loop", tearLoop()), ("whoosh", whoosh()), ("rim", rim()), ("bin-empty", emptyBin())]
for v in 1...3 {
    sounds.append(("rip-\(v)", rip(seed: UInt64(v * 13))))
    sounds.append(("rustle-\(v)", rustle(seed: UInt64(v * 29))))
    sounds.append(("crumple-\(v)", crumple(seed: UInt64(v * 41))))
}
for v in 1...2 { sounds.append(("thunk-\(v)", thunk(seed: UInt64(v)))) }
for v in 1...5 { sounds.append(("perf-\(v)", perforation(seed: UInt64(v * 97)))) }

for (name, buf) in sounds {
    try writeWAV(buf, to: dir.appendingPathComponent("\(name).wav"))
    print(String(format: "%@ %.2fs", name, Double(buf.count) / sampleRate))
}
