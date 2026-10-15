import RasiCore
import SwiftUI

/// The printed board the pad can hang on, like the one in the reference calendar.
enum BoardStyle: String, Codable, CaseIterable {
    case none
    case temple
    case kolam
    case plain
    case custom

    var title: String {
        switch self {
        case .none: "No Board"
        case .temple: "Temple"
        case .kolam: "Kolam & Lamp"
        case .plain: "Plain"
        case .custom: "Your Own Picture"
        }
    }

    /// Board size in sheet points (at scale 1), and where the pad's top-left sits on it.
    /// The pad hangs over the bottom edge, as tear-off pads on boards do.
    static let size = CGSize(width: 480, height: 464)
    static let padOrigin = CGPoint(x: 90, y: 150)
    /// The coloured band across the board behind the pad.
    static let band = (top: CGFloat(300), height: CGFloat(118))
}

/// A cheap glossy printed board: art at the top, a band across with the brand on the left and
/// the year on the right, a nail at the top. The pad is drawn on top by `PadView`.
struct BoardView: View {
    let style: BoardStyle
    let year: Int
    var image: NSImage?
    @Environment(\.cardTheme) private var theme

    private static let band = Color(red: 0.05, green: 0.42, blue: 0.43)

    var body: some View {
        let size = CGSize(width: theme.u(BoardStyle.size.width), height: theme.u(BoardStyle.size.height))
        ZStack(alignment: .topLeading) {
            background(size)

            // Band, brand and year.
            Rectangle().fill(Self.band)
                .frame(width: size.width, height: theme.u(BoardStyle.band.height))
                .offset(y: theme.u(BoardStyle.band.top))
            sideText(size)
            // The printer's credit, as on every real calendar board.
            Text("Printed at RASI PALAN PRESS\nDESKTOP-1")
                .font(.system(size: theme.u(5.5), weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: theme.u(BoardStyle.padOrigin.x))
                .offset(x: size.width - theme.u(BoardStyle.padOrigin.x),
                        y: theme.u(BoardStyle.band.top + BoardStyle.band.height - 20))

            // Nail.
            Circle().fill(LinearGradient(colors: [.white, .gray, .black.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: theme.u(9), height: theme.u(9))
                .shadow(color: .black.opacity(0.5), radius: theme.u(1), x: theme.u(1), y: theme.u(2))
                .offset(x: size.width / 2 - theme.u(4.5), y: theme.u(12))
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .colorEffect(ShaderLibrary.boardPrint(.float2(size), .float(theme.scale), .float(Float(year % 97))))
        .clipShape(RoundedRectangle(cornerRadius: theme.u(5)))
        .shadow(color: .black.opacity(0.35), radius: theme.u(8), x: 0, y: theme.u(5))
    }

    @ViewBuilder
    private func background(_ size: CGSize) -> some View {
        switch style {
        case .temple:
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color(red: 0.62, green: 0.12, blue: 0.20))
                // Sun rays behind the tower.
                RadialGradient(colors: [Color(red: 1, green: 0.8, blue: 0.35).opacity(0.75), .clear],
                               center: UnitPoint(x: 0.5, y: 0.12), startRadius: 0, endRadius: size.width * 0.45)
                Gopuram()
                    .frame(width: theme.u(132), height: theme.u(118))
                    .offset(x: size.width / 2 - theme.u(66), y: theme.u(20))
            }
        case .kolam:
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color(red: 0.07, green: 0.33, blue: 0.21))
                KolamPattern(spacing: theme.u(24))
                    .stroke(.white.opacity(0.45), lineWidth: max(1, theme.u(1.3)))
                Lamp()
                    .frame(width: theme.u(70), height: theme.u(125))
                    .offset(x: size.width / 2 - theme.u(35), y: theme.u(18))
            }
        case .plain, .none:
            Rectangle().fill(Color(red: 0.55, green: 0.10, blue: 0.16))
                .overlay(RoundedRectangle(cornerRadius: theme.u(3))
                    .stroke(Color(red: 0.85, green: 0.68, blue: 0.3), lineWidth: theme.u(3))
                    .padding(theme.u(10)))
        case .custom:
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .saturation(1.15)
            } else {
                Rectangle().fill(Color(red: 0.55, green: 0.10, blue: 0.16))
            }
        }
    }

    private func sideText(_ size: CGSize) -> some View {
        let side = theme.u(BoardStyle.padOrigin.x)
        return HStack(spacing: 0) {
            VStack(spacing: theme.u(-6)) {
                Text("ராசி")
                Text("பலன்")
            }
            .font(.custom("TamilSangamMN-Black", size: theme.u(30)))
            .minimumScaleFactor(0.5)
            .frame(width: side)

            Spacer()

            Text(String(year))
                .font(theme.numeral(40))
                .scaleEffect(x: 0.8, y: 1)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(width: side)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.3), radius: theme.u(1), y: theme.u(1))
        .frame(width: size.width, height: theme.u(BoardStyle.band.height))
        .offset(y: theme.u(BoardStyle.band.top))
    }
}

/// A stylised South Indian temple tower: stacked tiers, a barrel-vault crown and kalasams.
private struct Gopuram: View {
    private static let stone = Color(red: 0.95, green: 0.84, blue: 0.62)
    private static let shade = Color(red: 0.70, green: 0.50, blue: 0.30)
    private static let gold = Color(red: 0.95, green: 0.72, blue: 0.20)

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let tiers = 5
            let tierH = h * 0.13
            var bottom = h
            for i in 0..<tiers {
                let f = CGFloat(i) / CGFloat(tiers)
                let bw = w * (1 - f * 0.55), tw = w * (1 - (f + 0.2) * 0.55)
                let x0 = (w - bw) / 2, x1 = (w - tw) / 2
                var tier = Path()
                tier.move(to: CGPoint(x: x0, y: bottom))
                tier.addLine(to: CGPoint(x: x0 + bw, y: bottom))
                tier.addLine(to: CGPoint(x: x1 + tw, y: bottom - tierH))
                tier.addLine(to: CGPoint(x: x1, y: bottom - tierH))
                tier.closeSubpath()
                ctx.fill(tier, with: .color(Self.stone))
                ctx.stroke(tier, with: .color(Self.shade), lineWidth: 1)
                // Niches along each tier.
                let niches = 7 - i
                for n in 0..<niches {
                    let nx = x0 + bw * (CGFloat(n) + 0.5) / CGFloat(niches)
                    ctx.fill(Path(CGRect(x: nx - 1.5, y: bottom - tierH * 0.8, width: 3, height: tierH * 0.55)),
                             with: .color(Self.shade.opacity(0.8)))
                }
                bottom -= tierH
            }
            // Barrel-vault crown.
            let cw = w * 0.42, ch = h * 0.12
            let crown = Path(roundedRect: CGRect(x: (w - cw) / 2, y: bottom - ch, width: cw, height: ch),
                             cornerSize: CGSize(width: ch * 0.6, height: ch * 0.6))
            ctx.fill(crown, with: .color(Self.stone))
            ctx.stroke(crown, with: .color(Self.shade), lineWidth: 1)
            // Kalasams.
            for k in 0..<5 {
                let kx = (w - cw) / 2 + cw * (CGFloat(k) + 0.5) / 5
                ctx.fill(Path(ellipseIn: CGRect(x: kx - 3, y: bottom - ch - 8, width: 6, height: 8)), with: .color(Self.gold))
                ctx.fill(Path(CGRect(x: kx - 0.6, y: bottom - ch - 13, width: 1.2, height: 6)), with: .color(Self.gold))
            }
        }
    }
}

/// Dots with loops around them, like a pulli kolam.
private struct KolamPattern: Shape {
    let spacing: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        var y = rect.minY + spacing / 2
        var row = 0
        while y < rect.maxY {
            var x = rect.minX + spacing / 2 + (row % 2 == 0 ? 0 : spacing / 2)
            while x < rect.maxX {
                let r = spacing * 0.08
                p.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                // A petal loop around each dot.
                let l = spacing * 0.42
                p.move(to: CGPoint(x: x, y: y - l))
                p.addQuadCurve(to: CGPoint(x: x + l, y: y), control: CGPoint(x: x + l, y: y - l))
                p.addQuadCurve(to: CGPoint(x: x, y: y + l), control: CGPoint(x: x + l, y: y + l))
                p.addQuadCurve(to: CGPoint(x: x - l, y: y), control: CGPoint(x: x - l, y: y + l))
                p.addQuadCurve(to: CGPoint(x: x, y: y - l), control: CGPoint(x: x - l, y: y - l))
                x += spacing
            }
            y += spacing
            row += 1
        }
        return p
    }
}

/// A brass kuthu vilakku (standing oil lamp) with five flames.
private struct Lamp: View {
    private static let brass = LinearGradient(colors: [Color(red: 0.99, green: 0.85, blue: 0.45),
                                                       Color(red: 0.78, green: 0.55, blue: 0.15)],
                                              startPoint: .leading, endPoint: .trailing)

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            // Base.
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.1, y: h * 0.86, width: w * 0.8, height: h * 0.12)), with: .linearGradient(
                Gradient(colors: [Color(red: 0.99, green: 0.85, blue: 0.45), Color(red: 0.7, green: 0.48, blue: 0.12)]),
                startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: w, y: 0)))
            // Stem with knops.
            ctx.fill(Path(CGRect(x: w * 0.46, y: h * 0.35, width: w * 0.08, height: h * 0.53)),
                     with: .color(Color(red: 0.85, green: 0.62, blue: 0.2)))
            for f in [0.45, 0.6, 0.75] as [CGFloat] {
                ctx.fill(Path(ellipseIn: CGRect(x: w * 0.38, y: h * f, width: w * 0.24, height: h * 0.05)),
                         with: .color(Color(red: 0.92, green: 0.72, blue: 0.3)))
            }
            // Oil bowl.
            var bowl = Path()
            bowl.move(to: CGPoint(x: w * 0.05, y: h * 0.3))
            bowl.addQuadCurve(to: CGPoint(x: w * 0.95, y: h * 0.3), control: CGPoint(x: w * 0.5, y: h * 0.48))
            bowl.closeSubpath()
            ctx.fill(bowl, with: .color(Color(red: 0.9, green: 0.68, blue: 0.25)))
            // Flames along the rim.
            for i in 0..<5 {
                let fx = w * (0.12 + 0.19 * CGFloat(i))
                var flame = Path()
                flame.move(to: CGPoint(x: fx, y: h * 0.06))
                flame.addQuadCurve(to: CGPoint(x: fx, y: h * 0.29), control: CGPoint(x: fx + w * 0.07, y: h * 0.22))
                flame.addQuadCurve(to: CGPoint(x: fx, y: h * 0.06), control: CGPoint(x: fx - w * 0.07, y: h * 0.22))
                ctx.fill(flame, with: .radialGradient(Gradient(colors: [.white, .yellow, .orange.opacity(0.9)]),
                                                     center: CGPoint(x: fx, y: h * 0.24), startRadius: 0, endRadius: w * 0.08))
            }
            // Peacock finial.
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.42, y: 0, width: w * 0.16, height: h * 0.1)),
                     with: .color(Color(red: 0.85, green: 0.62, blue: 0.2)))
        }
    }
}
