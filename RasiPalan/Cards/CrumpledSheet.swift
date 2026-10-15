import RasiCore
import SwiftUI

/// A sheet part-way to (or fully) crumpled into a ball. t: 0 = flat … 1 = ball.
/// Drawn at full sheet size; the ball sits in the middle.
struct CrumpledSheet: View {
    let context: DayContext
    let layout: CardLayout
    var tornFromLeft = true
    var t: CGFloat
    @Environment(\.cardTheme) private var theme

    /// Ball diameter as a share of sheet width (lumps can poke out a little further).
    static let ballSize: CGFloat = 0.26

    var body: some View {
        let size = CGSize(width: theme.u(PadView.sheetSize.width), height: theme.u(PadView.sheetSize.height))
        SheetFace(context: context, layout: layout, torn: 1, tornFromLeft: tornFromLeft)
            .layerEffect(ShaderLibrary.crumple(.float2(size), .float(t), .float(theme.scale),
                                               .float(PrintedSheet<EmptyView>.seed(for: context.day))),
                         maxSampleOffset: size)
            .frame(width: size.width, height: size.height)
    }
}
