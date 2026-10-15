import RasiCore
import SwiftUI

/// Which language the card is printed in.
enum CardLanguage: String, Codable, CaseIterable {
    /// Mixed, the way Tamil Nadu calendars print it: Tamil terms, English weekday and numerals.
    case tamilEnglish
    case tamil
    case english

    var menuTitle: String {
        switch self {
        case .tamilEnglish: "Tamil + English"
        case .tamil: "Tamil (தமிழ்)"
        case .english: "English"
        }
    }
}

/// The two inks of a cheap two-colour press, plus the paper they're printed on.
/// Blocks print with `black` or `red` only; the ink shader turns them into plates.
enum Ink {
    static let paper = Color(red: 0.965, green: 0.955, blue: 0.925)
    static let black = Color(red: 0.10, green: 0.09, blue: 0.08)
    static let red = Color(red: 0.82, green: 0.10, blue: 0.12)
    static let faded = Color(red: 0.10, green: 0.09, blue: 0.08).opacity(0.35)
}

/// Everything a block needs to draw itself at the right size and in the right language.
/// All measurements in blocks go through `u(_:)` so the card stays vector-crisp at any scale.
struct CardTheme {
    var scale: CGFloat = 1
    var language: CardLanguage = .tamilEnglish
    /// Holes in the perforation along the top of each sheet.
    var perforations: Int = TearPhysics.defaults.holes

    func u(_ points: CGFloat) -> CGFloat { points * scale }

    /// Big letterpress numerals.
    func numeral(_ size: CGFloat) -> Font { .custom("Superclarendon-Black", size: u(size)) }

    /// English text in a slab serif, like old job-printing type.
    func latin(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "Superclarendon-Bold" : "Superclarendon-Regular", size: u(size))
    }

    func tamil(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "TamilSangamMN-Bold" : "TamilSangamMN", size: u(size))
    }

    /// The term in the card's language. Mixed cards use Tamil terms.
    func text(_ t: LocalizedText) -> String { language == .english ? t.en : t.ta }

    /// A term set in the matching script's font. English type is set a touch smaller,
    /// since the slab serif runs larger than Tamil at the same point size.
    func label(_ t: LocalizedText, _ size: CGFloat, bold: Bool = false) -> Text {
        language == .english
            ? Text(t.en).font(latin(size * 0.9, bold: bold))
            : Text(t.ta).font(tamil(size, bold: bold))
    }
}

private struct CardThemeKey: EnvironmentKey {
    static let defaultValue = CardTheme()
}

extension EnvironmentValues {
    var cardTheme: CardTheme {
        get { self[CardThemeKey.self] }
        set { self[CardThemeKey.self] = newValue }
    }
}
