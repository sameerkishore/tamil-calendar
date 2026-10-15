import AppKit
import SwiftUI

/// "Adjust Picture…": drag the photo to position it in the arched frame and zoom with the
/// slider. Every change shows on the board straight away.
@MainActor
final class PhotoCropWindowController {
    private let window: NSWindow

    init(image: NSImage, crop: PhotoCrop, onChange: @escaping (PhotoCrop) -> Void) {
        window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 360, height: 430),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Adjust Picture"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: PhotoCropView(image: image, crop: crop, onChange: onChange,
                                                                   done: { [weak window] in window?.close() }))
    }

    func show() {
        window.center()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}

private struct PhotoCropView: View {
    let image: NSImage
    @State var crop: PhotoCrop
    let onChange: (PhotoCrop) -> Void
    let done: () -> Void
    @State private var dragStart: PhotoCrop?

    var body: some View {
        let scale: CGFloat = 0.9
        let size = CGSize(width: BoardStyle.photoFrame.width * scale, height: BoardStyle.photoFrame.height * scale)
        VStack(spacing: 14) {
            Text("Drag the picture to position it. Use the slider to zoom.")
                .font(.callout).foregroundStyle(.secondary)

            PhotoPortrait(image: image, crop: crop)
                .frame(width: size.width, height: size.height)
                .environment(\.cardTheme, CardTheme(scale: scale))
                .contentShape(Rectangle())
                .gesture(DragGesture()
                    .onChanged { g in
                        let start = dragStart ?? crop
                        dragStart = start
                        // Dragging right moves the picture right, so the centre point moves left.
                        let span = displayedSize(in: size, zoom: start.zoom)
                        crop.x = clamp(start.x - g.translation.width / span.width)
                        crop.y = clamp(start.y - g.translation.height / span.height)
                    }
                    .onEnded { _ in dragStart = nil })
                .onHover { inside in
                    if inside { NSCursor.openHand.push() } else { NSCursor.pop() }
                }

            HStack {
                Image(systemName: "minus.magnifyingglass")
                Slider(value: $crop.zoom, in: 1...4)
                Image(systemName: "plus.magnifyingglass")
            }

            HStack {
                Button("Reset") { crop = PhotoCrop() }
                Spacer()
                Button("Done", action: done).keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .onChange(of: crop) { _, new in onChange(new) }
    }

    private func displayedSize(in frame: CGSize, zoom: Double) -> CGSize {
        let iw = max(image.size.width, 1), ih = max(image.size.height, 1)
        let s = max(frame.width / iw, frame.height / ih) * zoom
        return CGSize(width: iw * s, height: ih * s)
    }

    private func clamp(_ v: Double) -> Double { min(max(v, 0), 1) }
}
