import AppKit
import RasiCore
import SwiftUI

/// "Templates & Board…": live previews of today's sheet in every template, and the backing
/// board choices. Clicking one applies it straight away.
@MainActor
final class TemplateGalleryWindowController {
    private let window: NSWindow

    init(model: PadModel, chooseLayout: @escaping (String) -> Void, chooseBoard: @escaping (BoardStyle) -> Void,
         choosePicture: @escaping () -> Void, adjustPicture: @escaping () -> Void) {
        window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 760, height: 640),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Templates & Board"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: TemplateGalleryView(
            model: model, chooseLayout: chooseLayout, chooseBoard: chooseBoard, choosePicture: choosePicture,
            adjustPicture: adjustPicture))
    }

    func show() {
        window.center()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}

private struct TemplateGalleryView: View {
    let model: PadModel
    let chooseLayout: (String) -> Void
    let chooseBoard: (BoardStyle) -> Void
    let choosePicture: () -> Void
    let adjustPicture: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sheet design").font(.title3.bold())
            HStack(alignment: .top, spacing: 14) {
                ForEach(CardLayout.all) { layout in
                    let theme = CardTheme(scale: 0.52, language: model.language, perforations: model.perforations,
                                          paper: layout.paper)
                    Button { chooseLayout(layout.id) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            SheetFace(context: model.context, layout: layout)
                                .environment(\.cardTheme, theme)
                                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                                .overlay(selection(model.layout.id == layout.id))
                            Text(layout.name).font(.headline)
                            Text(layout.summary).font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(width: theme.u(PadView.sheetSize.width))
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            Text("Backing board").font(.title3.bold())
            Text("Hang the pad on a printed board, like the one on the wall at home.")
                .font(.callout).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 14) {
                ForEach(BoardStyle.allCases, id: \.self) { style in
                    Button { chooseBoard(style) } label: {
                        VStack(spacing: 6) {
                            BoardThumbnail(style: style, image: model.boardImage, crop: model.boardCrop,
                                           year: model.context.day.year)
                                .overlay(selection(model.board == style))
                            Text(style.title).font(.caption.bold())
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Spacer()
                if model.boardImage != nil {
                    Button("Adjust Picture…", action: adjustPicture)
                }
                Button(model.boardImage == nil ? "Choose Picture…" : "Change Picture…", action: choosePicture)
            }
        }
        .padding(20)
        .frame(width: 760)
    }

    private func selection(_ selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(Color.accentColor, lineWidth: selected ? 3 : 0)
            .padding(-4)
    }
}

/// A small picture of a board with a blank pad on it.
private struct BoardThumbnail: View {
    let style: BoardStyle
    let image: NSImage?
    var crop = PhotoCrop()
    let year: Int

    var body: some View {
        let scale: CGFloat = 0.25
        let theme = CardTheme(scale: scale)
        let content = PadView.contentSize(board: style)
        let origin = PadView.padOrigin(board: style)
        ZStack(alignment: .topLeading) {
            if style != .none {
                BoardView(style: style, year: year, image: image, crop: crop)
            }
            VStack(spacing: 0) {
                Rectangle().fill(Ink.red).frame(height: theme.u(PadView.gripHeight))
                Rectangle().fill(Ink.paper).frame(height: theme.u(PadView.sheetSize.height))
            }
            .frame(width: theme.u(PadView.sheetSize.width))
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            .offset(x: theme.u(origin.x), y: theme.u(origin.y))
        }
        .frame(width: theme.u(BoardStyle.temple.size.width), height: theme.u(content.height + 10), alignment: .top)
        .environment(\.cardTheme, theme)
    }
}
