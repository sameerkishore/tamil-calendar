import Foundation

/// How tearing feels, as plain-language choices.
struct TearPhysics: Codable, Equatable {
    enum Effort: String, Codable, CaseIterable { case light, medium, heavy }
    enum Perforation: String, Codable, CaseIterable { case fine, standard, coarse }

    var effort: Effort = .medium
    var perforation: Perforation = .standard
    var haptics = true

    static let defaults = TearPhysics()

    init() {}

    // Tolerant decoding: settings added (or dropped) later fall back to defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        effort = (try? c.decodeIfPresent(Effort.self, forKey: .effort)) ?? .medium
        perforation = (try? c.decodeIfPresent(Perforation.self, forKey: .perforation)) ?? .standard
        haptics = (try? c.decodeIfPresent(Bool.self, forKey: .haptics)) ?? true
    }

    /// How far across the sheet (as a share of its width) you drag to tear it off.
    var dragAcross: CGFloat {
        switch effort { case .light: 0.55; case .medium: 0.8; case .heavy: 1.1 }
    }

    /// Holes drawn along the top of each sheet.
    var holes: Int {
        switch perforation { case .fine: 44; case .standard: 28; case .coarse: 16 }
    }
}
