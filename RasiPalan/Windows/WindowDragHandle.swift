import AppKit
import SwiftUI

/// An invisible area that moves its window when dragged, using the system's own window drag
/// so it's smooth and snaps between displays like a normal window.
struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { HandleView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class HandleView: NSView {
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .openHand)
        }
    }
}

/// Corner grip that reports how far it has been dragged, in screen points, diagonally
/// (right or down grows). Uses screen coordinates because the window resizes under it mid-drag.
struct ResizeHandle: NSViewRepresentable {
    let onBegin: () -> Void
    let onDrag: (CGFloat) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = HandleView()
        view.onBegin = onBegin
        view.onDrag = onDrag
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? HandleView else { return }
        view.onBegin = onBegin
        view.onDrag = onDrag
    }

    private final class HandleView: NSView {
        var onBegin: () -> Void = {}
        var onDrag: (CGFloat) -> Void = { _ in }
        private var start: CGPoint = .zero

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            start = NSEvent.mouseLocation
            onBegin()
        }

        override func mouseDragged(with event: NSEvent) {
            let p = NSEvent.mouseLocation
            onDrag(((p.x - start.x) + (start.y - p.y)) / 2)
        }

        override func resetCursorRects() {
            if #available(macOS 15, *) {
                addCursorRect(bounds, cursor: .frameResize(position: .bottomRight, directions: .all))
            } else {
                addCursorRect(bounds, cursor: .crosshair)
            }
        }
    }
}
