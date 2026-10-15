import Foundation

/// How tearing feels, as plain-language choices. Each choice maps to tuning numbers in sheet
/// points (scaled with the pad); the defaults are the feel the app was tuned to.
struct TearPhysics: Codable, Equatable {
    enum Strength: String, Codable, CaseIterable { case light, medium, heavy }
    enum Perforation: String, Codable, CaseIterable { case fine, standard, coarse }
    enum ZipSpeed: String, Codable, CaseIterable { case slow, normal, quick }
    enum Feel: String, Codable, CaseIterable { case crisp, flexible, floppy }
    enum Swing: String, Codable, CaseIterable { case little, some, lots }

    var strength: Strength = .medium
    var perforation: Perforation = .standard
    var zipSpeed: ZipSpeed = .normal
    var feel: Feel = .crisp
    var swing: Swing = .some
    var haptics = true

    static let defaults = TearPhysics()

    init() {}

    // Tolerant decoding: settings added later fall back to defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        strength = (try? c.decodeIfPresent(Strength.self, forKey: .strength)) ?? .medium
        perforation = (try? c.decodeIfPresent(Perforation.self, forKey: .perforation)) ?? .standard
        zipSpeed = (try? c.decodeIfPresent(ZipSpeed.self, forKey: .zipSpeed)) ?? .normal
        feel = (try? c.decodeIfPresent(Feel.self, forKey: .feel)) ?? .crisp
        swing = (try? c.decodeIfPresent(Swing.self, forKey: .swing)) ?? .some
        haptics = (try? c.decodeIfPresent(Bool.self, forKey: .haptics)) ?? true
    }

    // MARK: - Tuning numbers

    /// Pull needed before the first hole gives.
    var firstHolePull: CGFloat {
        switch strength { case .light: 22; case .medium: 38; case .heavy: 58 }
    }

    /// Extra pull to break every hole after the first.
    var tearLength: CGFloat {
        switch strength { case .light: 150; case .medium: 240; case .heavy: 350 }
    }

    /// Holes along the top of each sheet.
    var holes: Int {
        switch perforation { case .fine: 44; case .standard: 28; case .coarse: 16 }
    }

    /// Shortest time between two holes giving way.
    var breakInterval: TimeInterval {
        switch zipSpeed { case .slow: 1.0 / 11; case .normal: 1.0 / 22; case .quick: 1.0 / 40 }
    }

    /// How far the paper bends before it's all tension.
    var maxBend: CGFloat {
        switch feel { case .crisp: 6; case .flexible: 13; case .floppy: 22 }
    }

    /// Radians a part-torn sheet can swing on its hinge.
    var maxSwing: CGFloat {
        switch swing { case .little: .pi / 7; case .some: .pi / 4; case .lots: .pi / 2.6 }
    }
}
