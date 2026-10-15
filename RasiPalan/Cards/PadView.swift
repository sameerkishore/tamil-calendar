import RasiCore
import SwiftUI

/// The whole desk object: red binding strip on top, the stack of sheets below.
struct PadView: View {
    let model: PadModel
    /// False when rendering offscreen (snapshots), where AppKit-backed views can't draw.
    var interactive = true

    static let sheetSize = CGSize(width: 300, height: 380)
    static let gripHeight: CGFloat = 26
    /// Transparent space around the pad so the shadow isn't clipped by the window.
    static let margin: CGFloat = 28
    /// How many sheet edges peek out under the top sheet to suggest thickness.
    static let stackDepth = 4
    static let stackStep: CGFloat = 2

    static var windowSize: CGSize {
        CGSize(width: sheetSize.width + margin * 2,
               height: gripHeight + sheetSize.height + CGFloat(stackDepth) * stackStep + margin * 2)
    }

    var body: some View {
        VStack(spacing: 0) {
            BindingStrip()
                .frame(height: Self.gripHeight)
                .overlay { if interactive { WindowDragHandle() } }
                .help("Drag here to move the calendar")
                .zIndex(1)

            ZStack(alignment: .top) {
                ForEach((1...Self.stackDepth).reversed(), id: \.self) { i in
                    Rectangle()
                        .fill(Ink.paper)
                        .overlay(Color.black.opacity(0.04 + Double(i) * 0.025))
                        .frame(width: Self.sheetSize.width, height: Self.sheetSize.height)
                        .offset(y: CGFloat(i) * Self.stackStep)
                }
                ClassicSheet(context: model.context)
                    .frame(width: Self.sheetSize.width, height: Self.sheetSize.height)
            }
            .frame(height: Self.sheetSize.height + CGFloat(Self.stackDepth) * Self.stackStep, alignment: .top)
        }
        .frame(width: Self.sheetSize.width)
        .compositingGroup()
        .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
        .padding(Self.margin)
    }
}

enum Ink {
    static let paper = Color(red: 0.97, green: 0.96, blue: 0.93)
    static let black = Color(red: 0.10, green: 0.09, blue: 0.08)
    static let red = Color(red: 0.82, green: 0.10, blue: 0.12)
    static let faded = Color(red: 0.10, green: 0.09, blue: 0.08).opacity(0.35)
}

/// The cloth-and-glue strip the sheets are bound into, with two staples.
struct BindingStrip: View {
    var body: some View {
        ZStack {
            Rectangle().fill(Ink.red)
            // Woven texture hint; the real paper/cloth shader comes in milestone 3.
            Rectangle()
                .fill(.white.opacity(0.10))
                .mask(
                    HStack(spacing: 3) {
                        ForEach(0..<80, id: \.self) { _ in Rectangle().frame(width: 1) }
                    }
                )
            HStack {
                Staple()
                Spacer()
                Staple()
            }
            .padding(.horizontal, 46)
        }
    }
}

private struct Staple: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(LinearGradient(colors: [.white.opacity(0.9), .gray], startPoint: .top, endPoint: .bottom))
            .frame(width: 22, height: 3)
            .shadow(color: .black.opacity(0.4), radius: 0.5, y: 0.5)
    }
}

#Preview {
    PadView(model: PadModel(context: DayContext(day: .today(), location: .chennai)))
}
