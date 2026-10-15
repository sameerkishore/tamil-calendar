import AppKit
import SwiftUI

/// Borderless, transparent window that lives on the desktop like a wall calendar.
final class PadWindow: NSWindow {
    init(size: CGSize) {
        super.init(contentRect: CGRect(origin: .zero, size: size),
                   styleMask: [.borderless],
                   backing: .buffered,
                   defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false               // the shadow is drawn in SwiftUI so it follows the paper's shape
        isReleasedWhenClosed = false
        isMovable = true                // only moved via the binding strip (performDrag)
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
    }

    override var canBecomeKey: Bool { true }
}

@MainActor
final class PadWindowController: NSObject, NSWindowDelegate {
    private let store: StateStore
    private let window: PadWindow

    /// Sits just above the desktop icons and below every normal app window.
    private static let desktopLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)

    init(store: StateStore) {
        self.store = store
        window = PadWindow(size: PadView.windowSize)
        super.init()

        window.contentView = NSHostingView(rootView: PadView(day: store.state.padDay))
        window.delegate = self
        applyLevel()

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    func show() {
        if let origin = store.state.padOrigin, isVisibleOnSomeScreen(origin: origin) {
            window.setFrameOrigin(origin)
        } else {
            window.setFrameOrigin(defaultOrigin())
        }
        window.orderFront(nil)
    }

    func resetPosition() {
        window.setFrameOrigin(defaultOrigin())
        window.orderFront(nil)
    }

    func applyLevel() {
        window.level = store.state.keepOnTop ? .floating : Self.desktopLevel
    }

    // MARK: - Positioning

    private func defaultOrigin() -> CGPoint {
        let visible = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        let size = window.frame.size
        return CGPoint(x: visible.maxX - size.width - 40, y: visible.maxY - size.height - 20)
    }

    /// True if at least the binding strip would be reachable on some display.
    private func isVisibleOnSomeScreen(origin: CGPoint) -> Bool {
        let frame = CGRect(origin: origin, size: window.frame.size)
        let grip = CGRect(x: frame.minX + PadView.margin,
                          y: frame.maxY - PadView.margin - PadView.gripHeight,
                          width: PadView.sheetSize.width,
                          height: PadView.gripHeight)
        return NSScreen.screens.contains { $0.visibleFrame.intersection(grip).width > 60 }
    }

    @objc private func screensChanged() {
        if !isVisibleOnSomeScreen(origin: window.frame.origin) {
            resetPosition()
        }
    }

    func windowDidMove(_ notification: Notification) {
        store.state.padOrigin = window.frame.origin
        store.save()
    }
}
