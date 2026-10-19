import SwiftUI

/// An sRGB colour that saves to JSON (SwiftUI's `Color` doesn't).
struct BoardColor: Codable, Equatable {
    var r: Double
    var g: Double
    var b: Double

    init(_ r: Double, _ g: Double, _ b: Double) { (self.r, self.g, self.b) = (r, g, b) }

    init(_ color: Color) {
        let c = NSColor(color).usingColorSpace(.sRGB) ?? .black
        self.init(Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent))
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b) }

    /// Perceived brightness, 0…1.
    var luminance: Double { 0.2126 * r + 0.7152 * g + 0.0722 * b }

    func mixed(with other: BoardColor, _ amount: Double) -> BoardColor {
        BoardColor(r + (other.r - r) * amount, g + (other.g - g) * amount, b + (other.b - b) * amount)
    }

    static let black = BoardColor(0, 0, 0)
    static let white = BoardColor(1, 1, 1)
}

/// The tiled print on the board stock.
enum BoardMotif: String, Codable, CaseIterable {
    case rosette, kolam, lattice, paisley, none

    var title: String {
        switch self {
        case .rosette: "Rosettes"
        case .kolam: "Kolam"
        case .lattice: "Lattice"
        case .paisley: "Paisley"
        case .none: "None"
        }
    }

    /// Tile size at normal density, in board points.
    var baseSpacing: CGFloat {
        switch self {
        case .rosette: 30
        case .kolam: 26
        case .lattice: 26
        case .paisley: 34
        case .none: 30
        }
    }
}

enum PatternDensity: String, Codable, CaseIterable {
    case sparse, normal, dense

    var title: String { rawValue.capitalized }

    var factor: CGFloat {
        switch self {
        case .sparse: 1.4
        case .normal: 1
        case .dense: 0.72
        }
    }
}

/// The colours and print of the Plain and Your Own Picture boards. The pattern ink is
/// derived from the background so the two always sit tone on tone; the frame colour
/// (the gold border) is the third pick.
struct BoardPalette: Codable, Equatable {
    var background: BoardColor
    var band: BoardColor
    var accent: BoardColor
    var motif: BoardMotif = .rosette
    var density: PatternDensity = .normal

    /// Where the board started life, and what everyone sees until they change it.
    static let classic = BoardPalette(background: BoardColor(0.55, 0.10, 0.16), band: BoardColor(0.05, 0.42, 0.43),
                                      accent: BoardColor(0.95, 0.76, 0.32))

    static let presets: [(name: String, palette: BoardPalette)] = [
        ("Classic", .classic),
        ("Peacock", BoardPalette(background: BoardColor(0.12, 0.14, 0.42), band: BoardColor(0.06, 0.50, 0.36),
                                 accent: BoardColor(0.95, 0.76, 0.32))),
        ("Turmeric", BoardPalette(background: BoardColor(0.36, 0.17, 0.08), band: BoardColor(0.93, 0.60, 0.12),
                                  accent: BoardColor(0.96, 0.90, 0.74))),
        ("Ink", BoardPalette(background: BoardColor(0.15, 0.15, 0.17), band: BoardColor(0.66, 0.22, 0.16),
                             accent: BoardColor(0.78, 0.80, 0.84))),
    ]

    /// The preset these three colours came from, if they still match one (the motif doesn't count).
    var presetName: String? {
        Self.presets.first { $0.palette.background == background && $0.palette.band == band && $0.palette.accent == accent }?.name
    }

    /// Tone-on-tone ink for the tiles: a shade darker than the stock, or lighter if it's already dark.
    var patternColor: Color {
        (background.luminance < 0.2 ? background.mixed(with: .white, 0.40) : background.mixed(with: .black, 0.25)).color
    }

    /// The deepest shade of the stock, behind the photo.
    var wellColor: Color { background.mixed(with: .black, 0.55).color }

    /// Text on the band: white, or dark ink when the band is too light for white.
    var bandTextIsDark: Bool { band.luminance > 0.55 }
    var bandText: Color { bandTextIsDark ? Color(red: 0.12, green: 0.10, blue: 0.08) : .white }

    var tileSpacing: CGFloat { motif.baseSpacing * density.factor }
}

/// The board's tiled print for a motif.
struct MotifPattern: Shape {
    let motif: BoardMotif
    let spacing: CGFloat

    func path(in rect: CGRect) -> Path {
        switch motif {
        case .rosette: RosettePattern(spacing: spacing).path(in: rect)
        case .kolam: KolamPattern(spacing: spacing).path(in: rect)
        case .lattice: LatticePattern(spacing: spacing).path(in: rect)
        case .paisley: PaisleyPattern(spacing: spacing).path(in: rect)
        case .none: Path()
        }
    }
}

/// Crossed diagonals with a small bead where they meet.
private struct LatticePattern: Shape {
    let spacing: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let h = rect.height
        var i = rect.minX - h
        while i < rect.maxX + h {
            p.move(to: CGPoint(x: i, y: rect.minY))
            p.addLine(to: CGPoint(x: i + h, y: rect.maxY))
            p.move(to: CGPoint(x: i + h, y: rect.minY))
            p.addLine(to: CGPoint(x: i, y: rect.maxY))
            i += spacing
        }
        let r = spacing * 0.07
        var y = rect.minY
        var row = 0
        while y < rect.maxY + spacing {
            var x = rect.minX + (row % 2 == 0 ? 0 : spacing / 2)
            while x < rect.maxX + spacing {
                p.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                x += spacing
            }
            y += spacing / 2
            row += 1
        }
        return p
    }
}

/// Mango-shaped paisley (boteh), alternate rows facing opposite ways.
private struct PaisleyPattern: Shape {
    let spacing: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let s = spacing * 0.46
        var y = rect.minY + spacing / 2
        var row = 0
        while y < rect.maxY + spacing {
            let f: CGFloat = row % 2 == 0 ? 1 : -1
            var x = rect.minX + spacing / 2 + (row % 2 == 0 ? 0 : spacing / 2)
            while x < rect.maxX + spacing {
                func pt(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint { CGPoint(x: x + dx * s * f, y: y + dy * s) }
                p.move(to: pt(0.95, -1.05))
                p.addCurve(to: pt(-0.55, 0.3), control1: pt(-0.15, -1.0), control2: pt(-0.6, -0.3))
                p.addCurve(to: pt(0, 0.9), control1: pt(-0.55, 0.7), control2: pt(-0.3, 0.9))
                p.addCurve(to: pt(0.55, 0.3), control1: pt(0.3, 0.9), control2: pt(0.55, 0.65))
                p.addCurve(to: pt(0.95, -1.05), control1: pt(0.55, -0.3), control2: pt(0.3, -0.75))
                // The bead in the bulb.
                let r = s * 0.13
                p.addEllipse(in: CGRect(x: x + 0.0 * s * f - r, y: y + 0.3 * s - r, width: r * 2, height: r * 2))
                x += spacing
            }
            y += spacing * 0.9
            row += 1
        }
        return p
    }
}
