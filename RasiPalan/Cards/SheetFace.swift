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
        .clipShape(TornSheetShape(seed: PrintedSheet<EmptyView>.seed(for: context.day),
                                  torn: torn, fromLeft: tornFromLeft, depth: theme.u(4)))
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

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let teeth = 70
        for i in 0...teeth {
            let f = CGFloat(i) / CGFloat(teeth)
            let tornHere = fromLeft ? f <= torn : f >= 1 - torn
            let n = sin(Float(i) * 12.9898 + seed * 78.233) * 43758.5453
            let jag = tornHere ? depth * (0.2 + 0.8 * CGFloat(n - n.rounded(.down))) : 0
            let p = CGPoint(x: rect.minX + rect.width * f, y: rect.minY + jag)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
