import AppKit
import RasiCore
import SwiftUI

/// "Templates & Board…": live previews of today's sheet in every template, and the backing
/// board choices. Clicking one applies it straight away.
@MainActor
final class TemplateGalleryWindowController {
    private let window: NSWindow

    init(model: PadModel, chooseLayout: @escaping (String) -> Void, chooseBoard: @escaping (BoardStyle) -> Void,
         choosePicture: @escaping () -> Void, customize: @escaping () -> Void, adjustPicture: @escaping () -> Void,
         setPhotoPrinted: @escaping (Bool) -> Void, customLayout: @escaping () -> CardLayout?) {
        window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 900, height: 680),
                          styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "Templates & Board"
        window.isReleasedWhenClosed = false
        window.contentMinSize = CGSize(width: 560, height: 420)
        window.contentView = NSHostingView(rootView: TemplateGalleryView(
            model: model, chooseLayout: chooseLayout, chooseBoard: chooseBoard, choosePicture: choosePicture,
            customize: customize, adjustPicture: adjustPicture, setPhotoPrinted: setPhotoPrinted,
            customLayout: customLayout))
    }

    func show() {
        window.center()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}

struct TemplateGalleryView: View {
    let model: PadModel
    let chooseLayout: (String) -> Void
    let chooseBoard: (BoardStyle) -> Void
    let choosePicture: () -> Void
    let customize: () -> Void
    let adjustPicture: () -> Void
    let setPhotoPrinted: (Bool) -> Void
    let customLayout: () -> CardLayout?
    /// Off only for debug snapshots, which can't render a scroll view.
    var scrolls = true

    /// Sheet previews wrap onto more rows when the window is narrow.
    private let sheetScale: CGFloat = 0.52
    private var columns: [GridItem] {
        let width = PadView.sheetSize.width * sheetScale
        return [GridItem(.adaptive(minimum: width, maximum: width), spacing: 14, alignment: .top)]
    }

    var body: some View {
        if scrolls { ScrollView { content } } else { content }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Sheet design").font(.title3.bold())
                Spacer()
                Button("Customize Sheet…", action: customize)
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                ForEach(CardLayout.all + [customLayout()].compactMap { $0 }) { layout in
                    let theme = CardTheme(scale: sheetScale, language: model.language, perforations: model.perforations,
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
            LazyVGrid(columns: [GridItem(.adaptive(minimum: BoardThumbnail.width, maximum: BoardThumbnail.width),
                                         spacing: 14, alignment: .top)],
                      alignment: .leading, spacing: 14) {
                ForEach(BoardStyle.allCases, id: \.self) { style in
                    Button { chooseBoard(style) } label: {
                        VStack(spacing: 6) {
                            BoardThumbnail(style: style, image: model.boardImage, crop: model.boardCrop,
                                           printed: model.boardPhotoPrinted,
                                           year: model.context.day.year)
                                .overlay(selection(model.board == style))
                            Text(style.title).font(.caption.bold())
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                if model.boardImage != nil {
                    Toggle("Vintage print effect", isOn: Binding(get: { model.boardPhotoPrinted },
                                                                 set: setPhotoPrinted))
                        .help("A faint halftone, grain and warm fade on your picture")
                }
                Spacer()
                if model.boardImage != nil {
                    Button("Adjust Picture…", action: adjustPicture)
                }
                Button(model.boardImage == nil ? "Choose Picture…" : "Change Picture…", action: choosePicture)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
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
    var printed = true
    let year: Int

    static let scale: CGFloat = 0.25
    static var width: CGFloat { BoardStyle.temple.size.width * scale }

    var body: some View {
        let scale = Self.scale
        let theme = CardTheme(scale: scale)
        let content = PadView.contentSize(board: style)
        let origin = PadView.padOrigin(board: style)
        ZStack(alignment: .topLeading) {
            if style != .none {
                BoardView(style: style, year: year, image: image, crop: crop, printed: printed)
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
