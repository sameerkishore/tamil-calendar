import RasiCore
import SwiftUI

/// The whole desk object: red binding strip on top, the stack of printed sheets below.
/// Everything is laid out in base "sheet points" and multiplied by the card scale.
struct PadView: View {
    let model: PadModel
    /// False when rendering offscreen (snapshots), where AppKit-backed views can't draw.
    var interactive = true
    var onResizeBegin: () -> Void = {}
    var onResize: (CGFloat) -> Void = { _ in }
    var onTearBegan: (CGPoint) -> Void = { _ in }
    var onTearMoved: (CGPoint, TimeInterval) -> Void = { _, _ in }
    var onTearEnded: (CGPoint, TimeInterval) -> Void = { _, _ in }

    static let sheetSize = CGSize(width: 300, height: 380)
    static let gripHeight: CGFloat = 26
    /// Transparent space around the pad so the shadow isn't clipped by the window.
    static let margin: CGFloat = 28
    /// How many sheet edges peek out under the top sheet to suggest thickness.
    static let stackDepth = 4
    static let stackStep: CGFloat = 2

    /// Binding strip, sheet and the edges of the stack under it.
    static let padHeight = gripHeight + sheetSize.height + CGFloat(stackDepth) * stackStep

    /// Where the pad's top-left sits within the content (on a board it hangs below the art).
    static func padOrigin(board: BoardStyle) -> CGPoint {
        board == .none ? .zero : board.padOrigin
    }

    /// Everything drawn (pad, plus board if any), in sheet points.
    static func contentSize(board: BoardStyle) -> CGSize {
        board == .none
            ? CGSize(width: sheetSize.width, height: padHeight)
            : CGSize(width: board.size.width, height: max(board.size.height, board.padOrigin.y + padHeight))
    }

    static func windowSize(scale: CGFloat, board: BoardStyle) -> CGSize {
        let c = contentSize(board: board)
        return CGSize(width: (c.width + margin * 2) * scale, height: (c.height + margin * 2) * scale)
    }

    /// Top-left of the top sheet within the window, in sheet points from the top-left.
    static func sheetOrigin(board: BoardStyle) -> CGPoint {
        let o = padOrigin(board: board)
        return CGPoint(x: margin + o.x, y: margin + o.y + gripHeight)
    }

    @State private var hovering = false

    var body: some View {
        let theme = model.theme()
        let sheet = CGSize(width: theme.u(Self.sheetSize.width), height: theme.u(Self.sheetSize.height))
        // While the top sheet is being torn it's drawn by the tear overlay; the next one shows here.
        let top = model.isTearing ? model.nextContext : model.context

        let origin = Self.padOrigin(board: model.board)
        let content = Self.contentSize(board: model.board)

        ZStack(alignment: .topLeading) {
            if model.board != .none {
                BoardView(style: model.board, year: top.day.year, image: model.boardImage, crop: model.boardCrop)
                    .overlay { if interactive { WindowDragHandle() } }
            }
            pad(theme: theme, sheet: sheet, top: top)
                .offset(x: theme.u(origin.x), y: theme.u(origin.y))
        }
        .frame(width: theme.u(content.width), height: theme.u(content.height), alignment: .topLeading)
        .padding(theme.u(Self.margin))
        .environment(\.cardTheme, theme)
        .onHover { hovering = $0 }
    }

    private func pad(theme: CardTheme, sheet: CGSize, top: DayContext) -> some View {
        VStack(spacing: 0) {
            BindingStrip(day: top.day)
                .frame(height: theme.u(Self.gripHeight))
                .overlay { if interactive { WindowDragHandle() } }
                .help("Drag here to move the calendar")
                .zIndex(1)

            ZStack(alignment: .top) {
                // Edges of the sheets underneath: older, more yellowed stock.
                ForEach((1...Self.stackDepth).reversed(), id: \.self) { i in
                    Rectangle()
                        .fill(theme.paper.color)
                        .overlay(Color(red: 0.45, green: 0.38, blue: 0.2).opacity(0.05 + Double(i) * 0.03))
                        .frame(width: sheet.width, height: sheet.height)
                        .offset(y: theme.u(CGFloat(i) * Self.stackStep))
                }

                // Show-through: tomorrow's sheet, faintly visible through thin paper.
                SheetFace(context: top, layout: model.layout,
                          showThrough: model.isTearing ? top.next() : model.nextContext,
                          extras: model.extras[top.day])
                    .overlay {
                        if interactive {
                            PointerTracker(began: onTearBegan, moved: onTearMoved, ended: onTearEnded)
                                .help("Pull the sheet to tear it off")
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                    if interactive && hovering {
                        ResizeGrip(onBegin: onResizeBegin, onDrag: onResize)
                            .frame(width: theme.u(18), height: theme.u(18))
                            .help("Drag to resize (or ⌘-scroll / pinch)")
                    }
                }
            }
            .frame(height: theme.u(Self.sheetSize.height + CGFloat(Self.stackDepth) * Self.stackStep), alignment: .top)
        }
        .frame(width: sheet.width)
        .compositingGroup()
        .shadow(color: .black.opacity(0.35), radius: theme.u(10), x: 0, y: theme.u(6))
    }
}

/// The cloth-and-glue strip the sheets are bound into, with two staples and the ragged
/// stubs of sheets already torn off.
struct BindingStrip: View {
    let day: CalendarDay
    @Environment(\.cardTheme) private var theme

    var body: some View {
        let seed = PrintedSheet<EmptyView>.seed(for: day)
        ZStack(alignment: .bottom) {
            Rectangle().fill(Ink.red)
            // Woven cloth texture.
            Rectangle()
                .fill(.white.opacity(0.10))
                .mask(
                    HStack(spacing: theme.u(2)) {
                        ForEach(0..<100, id: \.self) { _ in Rectangle().frame(width: max(0.5, theme.u(1))) }
                    }
                )
            HStack {
                Staple()
                Spacer()
                Staple()
            }
            .padding(.horizontal, theme.u(46))
            .frame(maxHeight: .infinity)

            TornStubs(seed: seed)
                .fill(Ink.paper)
                .overlay(TornStubs(seed: seed).stroke(.black.opacity(0.12), lineWidth: 0.5))
                .frame(height: theme.u(7))
                .offset(y: theme.u(5))
        }
    }
}

/// Jagged paper left behind under the binding where earlier sheets were torn off.
struct TornStubs: Shape {
    let seed: Float

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        let teeth = 46
        for i in stride(from: teeth, through: 0, by: -1) {
            let x = rect.minX + rect.width * CGFloat(i) / CGFloat(teeth)
            let n = sin(Float(i) * 12.9898 + seed * 78.233) * 43758.5453
            let jitter = CGFloat(n - n.rounded(.down))
            path.addLine(to: CGPoint(x: x, y: rect.minY + rect.height * (0.25 + 0.75 * jitter)))
        }
        path.closeSubpath()
        return path
    }
}

private struct Staple: View {
    @Environment(\.cardTheme) private var theme

    var body: some View {
        RoundedRectangle(cornerRadius: theme.u(1))
            .fill(LinearGradient(colors: [.white.opacity(0.9), .gray], startPoint: .top, endPoint: .bottom))
            .frame(width: theme.u(22), height: theme.u(3))
            .shadow(color: .black.opacity(0.4), radius: theme.u(0.5), y: theme.u(0.5))
    }
}

/// Bottom-right corner grip, shown on hover.
private struct ResizeGrip: View {
    let onBegin: () -> Void
    let onDrag: (CGFloat) -> Void

    var body: some View {
        ZStack {
            Canvas { ctx, size in
                for f in [0.3, 0.6, 0.9] as [CGFloat] {
                    var p = Path()
                    p.move(to: CGPoint(x: size.width * f, y: size.height - 2))
                    p.addLine(to: CGPoint(x: size.width - 2, y: size.height * f))
                    ctx.stroke(p, with: .color(.black.opacity(0.35)), lineWidth: 1)
                }
            }
            ResizeHandle(onBegin: onBegin, onDrag: onDrag)
        }
    }
}

#Preview {
    PadView(model: PadModel(context: DayContext(day: .today(), location: .chennai)))
}
