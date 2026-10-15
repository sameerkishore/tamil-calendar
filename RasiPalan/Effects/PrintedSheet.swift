import RasiCore
import SwiftUI

/// Turns crisp SwiftUI content into a sheet of cheap printed paper: newsprint stock under,
/// two-colour ink with press flaws on top (see Newsprint.metal).
struct PrintedSheet<Content: View>: View {
    let day: CalendarDay
    let size: CGSize
    /// 0 = fresh top sheet … 1 = old, yellowed stock.
    var age: Float = 0
    @ViewBuilder let content: Content
    @Environment(\.cardTheme) private var theme

    var body: some View {
        let seed = Self.seed(for: day)
        // Each day's red plate lands a little differently: 0.4–1.1 pt right, ±0.5 pt vertically.
        let redOffset = CGPoint(x: 0.4 + 0.7 * Self.fraction(seed * 3.7), y: -0.5 + Self.fraction(seed * 7.3))

        ZStack {
            Rectangle()
                .fill(theme.paper.color)
                .colorEffect(ShaderLibrary.newsprintPaper(
                    .float2(size), .float(theme.scale), .float(seed), .float(age)))

            switch theme.paper {
            case .newsprint:
                content
                    // Overfull sheets lose their last blocks, never the header.
                    .frame(width: size.width, height: size.height, alignment: .top)
                    .layerEffect(ShaderLibrary.newsprintInk(
                        .float(theme.scale), .float(seed), .float2(redOffset)),
                        maxSampleOffset: CGSize(width: theme.u(2), height: theme.u(2)))
                    .blendMode(.multiply)
            case .dark:
                content
                    // Overfull sheets lose their last blocks, never the header.
                    .frame(width: size.width, height: size.height, alignment: .top)
                    .layerEffect(ShaderLibrary.darkStockInk(
                        .float(theme.scale), .float(seed), .float2(redOffset)),
                        maxSampleOffset: CGSize(width: theme.u(2), height: theme.u(2)))
            }
        }
        .frame(width: size.width, height: size.height)
        .compositingGroup()
    }

    /// Stable per-date seed, so a sheet looks the same every time it's drawn.
    static func seed(for day: CalendarDay) -> Float {
        Float((day.year * 372 + day.month * 31 + day.day) % 997) * 0.731
    }

    private static func fraction(_ x: Float) -> CGFloat {
        CGFloat(x - x.rounded(.down))
    }
}
