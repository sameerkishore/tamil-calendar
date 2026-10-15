import AppKit
import SwiftUI

/// Drag anywhere to move the window; a click without movement is reported separately.
/// Also measures how fast the window was moving when let go (for throwing) and can show a
/// right-click menu.
final class DraggableHostingView<Content: View>: NSHostingView<Content> {
    var onDragStarted: () -> Void = {}
    /// Velocity at release in screen points per second (AppKit, y up).
    var onDragEnded: (CGVector) -> Void = { _ in }
    var onClick: () -> Void = {}
    var contextMenu: () -> NSMenu? = { nil }

    private var start: CGPoint = .zero
    private var startOrigin: CGPoint = .zero
    private var dragged = false
    private var samples: [(point: CGPoint, time: TimeInterval)] = []

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        start = NSEvent.mouseLocation
        startOrigin = window?.frame.origin ?? .zero
        dragged = false
        samples = [(start, event.timestamp)]
    }

    override func mouseDragged(with event: NSEvent) {
        let p = NSEvent.mouseLocation
        if !dragged && hypot(p.x - start.x, p.y - start.y) < 3 { return }
        if !dragged {
            NSCursor.closedHand.push()
            onDragStarted()
        }
        dragged = true
        window?.setFrameOrigin(CGPoint(x: startOrigin.x + p.x - start.x, y: startOrigin.y + p.y - start.y))
        samples.append((p, event.timestamp))
        samples.removeAll { event.timestamp - $0.time > 0.1 }
    }

    override func mouseUp(with event: NSEvent) {
        if dragged {
            NSCursor.pop()
            onDragEnded(releaseVelocity(at: event.timestamp))
        } else {
            onClick()
        }
    }

    /// Average velocity over the last ~80 ms of the drag; zero if the hand had stopped.
    private func releaseVelocity(at time: TimeInterval) -> CGVector {
        let recent = samples.filter { time - $0.time < 0.08 }
        guard let first = recent.first, let last = recent.last, last.time - first.time > 0.008 else { return .zero }
        let dt = last.time - first.time
        return CGVector(dx: (last.point.x - first.point.x) / dt, dy: (last.point.y - first.point.y) / dt)
    }

    override func menu(for event: NSEvent) -> NSMenu? { contextMenu() }
}
