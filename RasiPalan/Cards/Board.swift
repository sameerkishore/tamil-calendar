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
    /// The pad hangs over the bottom edge, as tear-off pads on boards do. The photo board is
    /// taller, so the picture sits entirely above the pad like a deity portrait.
    var size: CGSize { self == .custom ? CGSize(width: 480, height: 664) : CGSize(width: 480, height: 464) }
    var padOrigin: CGPoint { CGPoint(x: 90, y: self == .custom ? 350 : 150) }
    /// The coloured band across the board behind the pad.
    var band: (top: CGFloat, height: CGFloat) { (self == .custom ? 500 : 300, 118) }
    /// The arched photo frame on the photo board.
    static let photoFrame = CGRect(x: 75, y: 30, width: 330, height: 300)
}

/// A cheap glossy printed board: art at the top, a band across with the brand on the left and
/// the year on the right, a nail at the top. The pad is drawn on top by `PadView`.
struct BoardView: View {
    let style: BoardStyle
    let year: Int
    var image: NSImage?
    var crop = PhotoCrop()
    /// Vintage print effect on the picture (custom board only).
    var printed = true
    @Environment(\.cardTheme) private var theme

    private static let band = Color(red: 0.05, green: 0.42, blue: 0.43)

    var body: some View {
        let size = CGSize(width: theme.u(style.size.width), height: theme.u(style.size.height))
        ZStack(alignment: .topLeading) {
            background(size)

            // Band, brand and year.
            Rectangle().fill(Self.band)
                .frame(width: size.width, height: theme.u(style.band.height))
                .offset(y: theme.u(style.band.top))
            sideText(size)
            // The printer's credit, as on every real calendar board.
            Text("Printed at RASI PALAN PRESS\nDESKTOP-1")
                .font(.system(size: theme.u(5.5), weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: theme.u(style.padOrigin.x))
                .offset(x: size.width - theme.u(style.padOrigin.x),
                        y: theme.u(style.band.top + style.band.height - 20))

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
            // A whole scene, drawn in sheet points and scaled to the board.
            TempleScene()
                .frame(width: style.size.width, height: style.size.height)
                .scaleEffect(theme.scale, anchor: .topLeading)
                .frame(width: size.width, height: size.height, alignment: .topLeading)
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
                // Printed card, not flat colour: tone-on-tone rosettes and a fine linen grain.
                .overlay(RosettePattern(spacing: theme.u(30))
                    .stroke(Color(red: 0.42, green: 0.05, blue: 0.11).opacity(0.7), lineWidth: max(1, theme.u(1.1))))
                .colorEffect(ShaderLibrary.linen(.float(theme.scale)))
                .overlay(RoundedRectangle(cornerRadius: theme.u(3))
                    .stroke(Color(red: 0.85, green: 0.68, blue: 0.3), lineWidth: theme.u(3))
                    .padding(theme.u(10)))
        case .custom:
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color(red: 0.55, green: 0.10, blue: 0.16))
                    .overlay(RosettePattern(spacing: theme.u(30))
                        .stroke(Color(red: 0.42, green: 0.05, blue: 0.11).opacity(0.7), lineWidth: max(1, theme.u(1.1))))
                    .colorEffect(ShaderLibrary.linen(.float(theme.scale)))
                PhotoPortrait(image: image, crop: crop, printed: printed)
                    .frame(width: theme.u(BoardStyle.photoFrame.width), height: theme.u(BoardStyle.photoFrame.height))
                    .offset(x: theme.u(BoardStyle.photoFrame.minX), y: theme.u(BoardStyle.photoFrame.minY))
            }
        }
    }

    private func sideText(_ size: CGSize) -> some View {
        let side = theme.u(style.padOrigin.x)
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
        .frame(width: size.width, height: theme.u(style.band.height))
        .offset(y: theme.u(style.band.top))
    }
}

/// Which part of the user's photo shows in the frame: zoom (1 = just fills it) and the point
/// of the photo at the frame's centre (0…1 across and down).
struct PhotoCrop: Codable, Equatable {
    var zoom: Double = 1
    var x: Double = 0.5
    var y: Double = 0.4
}

/// The user's photo in a gold-bordered arched frame, cropped as they chose.
struct PhotoPortrait: View {
    let image: NSImage?
    let crop: PhotoCrop
    var printed = true
    @Environment(\.cardTheme) private var theme

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.25, green: 0.05, blue: 0.08)
                if let image {
                    // Printed on the board like the rest of it: a four-colour halftone.
                    CroppedImage(image: image, crop: crop, size: geo.size)
                        .saturation(1.12)
                        .contrast(1.05)
                        .layerEffect(ShaderLibrary.halftone(.float(theme.scale)),
                                     maxSampleOffset: CGSize(width: theme.u(3), height: theme.u(3)),
                                     isEnabled: printed)
                } else {
                    Text("Choose a picture in\nTemplates & Board")
                        .font(theme.latin(12))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .clipShape(Arch())
            .overlay(Arch().stroke(Color(red: 0.95, green: 0.76, blue: 0.32), lineWidth: theme.u(5)))
            .overlay(Arch().inset(by: theme.u(7)).stroke(Color(red: 0.95, green: 0.76, blue: 0.32).opacity(0.7), lineWidth: max(1, theme.u(1))))
            .shadow(color: .black.opacity(0.35), radius: theme.u(3), y: theme.u(2))
        }
    }
}

/// An image filling `size`, zoomed and positioned by `crop`, never leaving gaps.
struct CroppedImage: View {
    let image: NSImage
    let crop: PhotoCrop
    let size: CGSize

    var body: some View {
        let iw = max(image.size.width, 1), ih = max(image.size.height, 1)
        let s = max(size.width / iw, size.height / ih) * crop.zoom
        let dw = iw * s, dh = ih * s
        // Put the chosen point at the centre, then keep the image covering the frame.
        let ox = min(0, max(size.width - dw, size.width / 2 - CGFloat(crop.x) * dw))
        let oy = min(0, max(size.height - dh, size.height / 2 - CGFloat(crop.y) * dh))
        Image(nsImage: image)
            .resizable()
            .frame(width: dw, height: dh)
            .offset(x: ox, y: oy)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .clipped()
    }
}

/// A rectangle with a rounded, temple-doorway arch on top.
struct Arch: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let archH = r.width * 0.32
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + archH))
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY),
                   control1: CGPoint(x: r.minX, y: r.minY + archH * 0.45),
                   control2: CGPoint(x: r.midX - r.width * 0.28, y: r.minY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.minY + archH),
                   control1: CGPoint(x: r.midX + r.width * 0.28, y: r.minY),
                   control2: CGPoint(x: r.maxX, y: r.minY + archH * 0.45))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }

    func inset(by amount: CGFloat) -> Arch {
        var a = self
        a.insetAmount += amount
        return a
    }
}

/// Temple at sunset, in board points (480 × 464): sky, sun, a painted gopuram with striped
/// compound walls running off to either side, coconut palms and birds. The pad hides the lower
/// middle, so everything important sits above it or at the sides.
private struct TempleScene: View {
    private static let stone = Color(red: 0.96, green: 0.86, blue: 0.66)
    private static let shade = Color(red: 0.62, green: 0.42, blue: 0.24)
    private static let gold = Color(red: 0.98, green: 0.75, blue: 0.22)
    private static let paints: [Color] = [
        Color(red: 0.85, green: 0.22, blue: 0.20), Color(red: 0.16, green: 0.45, blue: 0.75),
        Color(red: 0.20, green: 0.58, blue: 0.32), Color(red: 0.95, green: 0.70, blue: 0.18),
        Color(red: 0.90, green: 0.45, blue: 0.65),
    ]

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, mid = w / 2
            let ground: CGFloat = 148   // just above where the pad starts

            // Sky: saffron to pink, deepening to the board's maroon at the band.
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(red: 0.99, green: 0.62, blue: 0.22), location: 0),
                    .init(color: Color(red: 0.93, green: 0.40, blue: 0.36), location: 0.22),
                    .init(color: Color(red: 0.62, green: 0.12, blue: 0.20), location: 0.45),
                    .init(color: Color(red: 0.55, green: 0.09, blue: 0.17), location: 1),
                ]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))

            // Sun and its rays behind the tower.
            for i in 0..<16 {
                let a = CGFloat(i) / 16 * .pi * 2
                var ray = Path()
                ray.move(to: CGPoint(x: mid, y: 70))
                ray.addLine(to: CGPoint(x: mid + cos(a - 0.06) * 260, y: 70 + sin(a - 0.06) * 260))
                ray.addLine(to: CGPoint(x: mid + cos(a + 0.06) * 260, y: 70 + sin(a + 0.06) * 260))
                ray.closeSubpath()
                ctx.fill(ray, with: .color(.white.opacity(0.07)))
            }
            ctx.fill(Path(ellipseIn: CGRect(x: mid - 60, y: 10, width: 120, height: 120)),
                     with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.93, blue: 0.6), Color(red: 1, green: 0.75, blue: 0.3).opacity(0)]),
                                           center: CGPoint(x: mid, y: 70), startRadius: 10, endRadius: 60))

            // Birds.
            for (bx, by, bs) in [(70.0, 40.0, 7.0), (92.0, 30.0, 5.0), (395.0, 48.0, 6.0), (412.0, 36.0, 4.5)] as [(CGFloat, CGFloat, CGFloat)] {
                var bird = Path()
                bird.move(to: CGPoint(x: bx - bs, y: by - bs * 0.3))
                bird.addQuadCurve(to: CGPoint(x: bx, y: by), control: CGPoint(x: bx - bs * 0.5, y: by - bs * 0.6))
                bird.addQuadCurve(to: CGPoint(x: bx + bs, y: by - bs * 0.3), control: CGPoint(x: bx + bs * 0.5, y: by - bs * 0.6))
                ctx.stroke(bird, with: .color(.black.opacity(0.55)), lineWidth: 1.2)
            }

            // Coconut palms at the edges.
            palm(ctx, base: CGPoint(x: 28, y: ground + 4), lean: 14, height: 110)
            palm(ctx, base: CGPoint(x: 452, y: ground + 4), lean: -16, height: 120)

            // Compound walls with red and white vertical stripes, running off both sides.
            let wallTop = ground - 26
            for x in stride(from: CGFloat(0), to: w, by: 10) {
                let red = Int(x / 10) % 2 == 0
                ctx.fill(Path(CGRect(x: x, y: wallTop, width: 10, height: 30)),
                         with: .color(red ? Color(red: 0.80, green: 0.18, blue: 0.15) : Color(red: 0.97, green: 0.93, blue: 0.85)))
            }
            ctx.fill(Path(CGRect(x: 0, y: wallTop - 4, width: w, height: 5)), with: .color(Self.stone))
            ctx.fill(Path(CGRect(x: 0, y: wallTop + 1, width: w, height: 1)), with: .color(Self.shade.opacity(0.6)))

            // The gopuram.
            gopuram(ctx, centerX: mid, base: ground, width: 150, height: 112)
        }
    }

    private func gopuram(_ ctx: GraphicsContext, centerX: CGFloat, base: CGFloat, width: CGFloat, height: CGFloat) {
        // Stone gateway base with a dark doorway.
        let baseH = height * 0.18
        let baseRect = CGRect(x: centerX - width / 2, y: base - baseH, width: width, height: baseH)
        ctx.fill(Path(baseRect), with: .color(Self.stone))
        ctx.stroke(Path(baseRect), with: .color(Self.shade), lineWidth: 1)
        var door = Path()
        door.move(to: CGPoint(x: centerX - 11, y: base))
        door.addLine(to: CGPoint(x: centerX - 11, y: base - baseH * 0.6))
        door.addQuadCurve(to: CGPoint(x: centerX + 11, y: base - baseH * 0.6), control: CGPoint(x: centerX, y: base - baseH * 1.05))
        door.addLine(to: CGPoint(x: centerX + 11, y: base))
        ctx.fill(door, with: .color(Color(red: 0.2, green: 0.08, blue: 0.06)))

        // Seven painted tiers, narrowing upwards, each with a ledge and figures in niches.
        let tiers = 7
        let tierH = height * 0.095
        var bottom = base - baseH
        for i in 0..<tiers {
            let f = CGFloat(i) / CGFloat(tiers)
            let bw = width * (0.92 - f * 0.5), tw = width * (0.92 - (f + 1 / CGFloat(tiers)) * 0.5)
            var tier = Path()
            tier.move(to: CGPoint(x: centerX - bw / 2, y: bottom))
            tier.addLine(to: CGPoint(x: centerX + bw / 2, y: bottom))
            tier.addLine(to: CGPoint(x: centerX + tw / 2, y: bottom - tierH))
            tier.addLine(to: CGPoint(x: centerX - tw / 2, y: bottom - tierH))
            tier.closeSubpath()
            ctx.fill(tier, with: .linearGradient(Gradient(colors: [Self.stone.opacity(0.85), Self.stone, Self.shade.opacity(0.6)]),
                                                 startPoint: CGPoint(x: centerX - bw / 2, y: 0), endPoint: CGPoint(x: centerX + bw / 2, y: 0)))
            // Ledge.
            ctx.fill(Path(CGRect(x: centerX - tw / 2 - 2, y: bottom - tierH - 1.5, width: tw + 4, height: 2.5)), with: .color(Self.shade))
            // Painted figures.
            let niches = max(3, 9 - i)
            for n in 0..<niches {
                let nx = centerX - bw / 2 + bw * (CGFloat(n) + 0.5) / CGFloat(niches)
                let paint = Self.paints[(n + i * 2) % Self.paints.count]
                ctx.fill(Path(roundedRect: CGRect(x: nx - 2.2, y: bottom - tierH * 0.82, width: 4.4, height: tierH * 0.62),
                              cornerRadius: 2), with: .color(paint))
                ctx.fill(Path(ellipseIn: CGRect(x: nx - 1.6, y: bottom - tierH * 0.95, width: 3.2, height: 3.2)), with: .color(paint.opacity(0.9)))
            }
            bottom -= tierH
        }

        // Barrel-vault crown (shala) with horned ends and golden kalasams.
        let cw = width * 0.44, ch = height * 0.1
        let crown = Path(roundedRect: CGRect(x: centerX - cw / 2, y: bottom - ch, width: cw, height: ch),
                         cornerSize: CGSize(width: ch * 0.7, height: ch * 0.7))
        ctx.fill(crown, with: .color(Self.stone))
        ctx.stroke(crown, with: .color(Self.shade), lineWidth: 1)
        for side in [-1.0, 1.0] as [CGFloat] {
            var horn = Path()
            horn.move(to: CGPoint(x: centerX + side * cw / 2, y: bottom - ch * 0.6))
            horn.addQuadCurve(to: CGPoint(x: centerX + side * (cw / 2 + 7), y: bottom - ch * 1.3),
                              control: CGPoint(x: centerX + side * (cw / 2 + 7), y: bottom - ch * 0.5))
            ctx.stroke(horn, with: .color(Self.shade), lineWidth: 2)
        }
        for k in 0..<7 {
            let kx = centerX - cw / 2 + cw * (CGFloat(k) + 0.5) / 7
            ctx.fill(Path(ellipseIn: CGRect(x: kx - 3, y: bottom - ch - 8, width: 6, height: 8)), with: .color(Self.gold))
            ctx.fill(Path(CGRect(x: kx - 0.6, y: bottom - ch - 13, width: 1.2, height: 6)), with: .color(Self.gold))
        }
    }

    private func palm(_ ctx: GraphicsContext, base: CGPoint, lean: CGFloat, height: CGFloat) {
        let top = CGPoint(x: base.x + lean, y: base.y - height)
        var trunk = Path()
        trunk.move(to: base)
        trunk.addQuadCurve(to: top, control: CGPoint(x: base.x + lean * 0.2, y: base.y - height * 0.5))
        let dark = Color(red: 0.12, green: 0.10, blue: 0.08).opacity(0.85)
        ctx.stroke(trunk, with: .color(dark), lineWidth: 4)
        for i in 0..<7 {
            let a = -CGFloat.pi / 2 + (CGFloat(i) - 3) * 0.5
            let len: CGFloat = 34
            let tip = CGPoint(x: top.x + cos(a) * len, y: top.y + sin(a) * len * 0.6 + 14)
            var frond = Path()
            frond.move(to: top)
            frond.addQuadCurve(to: tip, control: CGPoint(x: top.x + cos(a) * len * 0.6, y: top.y + sin(a) * len * 0.6 - 6))
            ctx.stroke(frond, with: .color(dark), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
    }
}

/// Tone-on-tone rosettes for printed board stock.
private struct RosettePattern: Shape {
    let spacing: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        var y = rect.minY
        var row = 0
        while y < rect.maxY + spacing {
            var x = rect.minX + (row % 2 == 0 ? 0 : spacing / 2)
            while x < rect.maxX + spacing {
                let r = spacing * 0.22
                for k in 0..<8 {
                    let a = CGFloat(k) / 8 * .pi * 2
                    p.addEllipse(in: CGRect(x: x + cos(a) * r - r * 0.35, y: y + sin(a) * r - r * 0.35,
                                            width: r * 0.7, height: r * 0.7))
                }
                p.addEllipse(in: CGRect(x: x - r * 0.25, y: y - r * 0.25, width: r * 0.5, height: r * 0.5))
                x += spacing
            }
            y += spacing * 0.866
            row += 1
        }
        return p
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
