import AppKit
import SwiftUI

/// Reports a mouse drag in screen coordinates (AppKit, y up). The view that receives
/// mouse-down keeps getting the drag even when the pointer leaves its window, which is what
/// lets a sheet be pulled far away from the pad.
struct PointerTracker: NSViewRepresentable {
    var began: (CGPoint) -> Void
    var moved: (CGPoint, TimeInterval) -> Void
    var ended: (CGPoint, TimeInterval) -> Void
    var cursor: NSCursor = .openHand

    func makeNSView(context: Context) -> TrackerView {
        let view = TrackerView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: TrackerView, context: Context) {
        view.began = began
        view.moved = moved
        view.ended = ended
        view.cursor = cursor
    }

    final class TrackerView: NSView {
        var began: (CGPoint) -> Void = { _ in }
        var moved: (CGPoint, TimeInterval) -> Void = { _, _ in }
        var ended: (CGPoint, TimeInterval) -> Void = { _, _ in }
        var cursor: NSCursor = .openHand

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            NSCursor.closedHand.push()
            began(NSEvent.mouseLocation)
        }

        override func mouseDragged(with event: NSEvent) {
            moved(NSEvent.mouseLocation, event.timestamp)
        }

        override func mouseUp(with event: NSEvent) {
            NSCursor.pop()
            ended(NSEvent.mouseLocation, event.timestamp)
        }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: cursor)
        }
    }
}
