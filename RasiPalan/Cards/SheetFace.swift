import RasiCore
import SwiftUI

/// One printed sheet's front: newsprint, ink and the day's layout. Used on the pad,
/// while tearing, and for sheets floating on the desktop.
struct SheetFace: View {
    let context: DayContext
    let layout: CardLayout
    /// The sheet underneath, faintly visible through thin paper (only while on the pad).
    var showThrough: DayContext? = nil
    /// How much of the top edge has been torn (0…1), and from which side.
    var torn: CGFloat = 0
    var tornFromLeft = true
    @Environment(\.cardTheme) private var theme

    var size: CGSize {
        CGSize(width: theme.u(PadView.sheetSize.width), height: theme.u(PadView.sheetSize.height))
    }

    var body: some View {
        PrintedSheet(day: context.day, size: size) {
            ZStack {
                if let showThrough {
                    CardSheetView(layout: layout, context: showThrough)
                        .opacity(0.07)
                        .blur(radius: theme.u(0.8))
                        .offset(x: theme.u(1.5), y: theme.u(-1))
                }
                CardSheetView(layout: layout, context: context)
            }
        }
        .overlay(alignment: .top) {
            if torn < 1 {
                PerforationRow(torn: torn, fromLeft: tornFromLeft)
                    .frame(height: theme.u(2))
                    .padding(.top, theme.u(3))
            }
        }
        .clipShape(TornSheetShape(seed: PrintedSheet<EmptyView>.seed(for: context.day),
                                  torn: torn, fromLeft: tornFromLeft, depth: theme.u(4.5)))
    }
}

/// The row of punched holes the sheet tears along. Holes already torn through are gone.
struct PerforationRow: View {
    var torn: CGFloat
    var fromLeft: Bool

    var body: some View {
        Canvas { ctx, size in
            let n = Perforation.count
            let step = size.width / CGFloat(n)
            let r = size.height / 2
            for i in 0..<n {
                let f = (CGFloat(i) + 0.5) / CGFloat(n)
                let gone = fromLeft ? f < torn : f > 1 - torn
                if gone { continue }
                let rect = CGRect(x: step * (CGFloat(i) + 0.5) - r * 1.4, y: 0, width: r * 2.8, height: r * 2)
                ctx.fill(Path(roundedRect: rect, cornerRadius: r), with: .color(.black.opacity(0.22)))
            }
        }
    }
}

/// The sheet's outline, with a ragged top edge along the part torn from the perforation.
struct TornSheetShape: Shape {
    let seed: Float
    var torn: CGFloat
    var fromLeft: Bool
    var depth: CGFloat

    var animatableData: CGFloat {
        get { torn }
        set { torn = newValue }
    }

    /// Torn perforated paper: a scallop where each hole was, with ragged fibres in between.
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let perHole = 6
        let teeth = Perforation.count * perHole
        for i in 0...teeth {
            let f = CGFloat(i) / CGFloat(teeth)
            let tornHere = fromLeft ? f <= torn : f >= 1 - torn
            var y: CGFloat = 0
            if tornHere {
                let n = sin(Float(i) * 12.9898 + seed * 78.233) * 43758.5453
                let jitter = CGFloat(n - n.rounded(.down))
                let scallop = abs(sin(.pi * CGFloat(i) / CGFloat(perHole)))
                y = depth * (0.25 + 0.5 * scallop + 0.25 * jitter)
            }
            let p = CGPoint(x: rect.minX + rect.width * f, y: rect.minY + y)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
