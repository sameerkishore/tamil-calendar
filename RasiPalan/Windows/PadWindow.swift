import AppKit
import RasiCore
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

/// Hosting view that turns ⌘-scroll and trackpad pinch into resize requests.
final class PadHostingView: NSHostingView<PadView> {
    var onScaleBy: ((CGFloat) -> Void)?

    override func scrollWheel(with event: NSEvent) {
        guard event.modifierFlags.contains(.command) else { return super.scrollWheel(with: event) }
        let sensitivity: CGFloat = event.hasPreciseScrollingDeltas ? 0.004 : 0.04
        onScaleBy?(exp(event.scrollingDeltaY * sensitivity))
    }

    override func magnify(with event: NSEvent) {
        onScaleBy?(1 + event.magnification)
    }
}

@MainActor
final class PadWindowController: NSObject, NSWindowDelegate {
    static let scaleRange: ClosedRange<CGFloat> = 0.5...2.5

    private let store: StateStore
    private let model: PadModel
    private let window: PadWindow
    private var scaleAtDragStart: CGFloat = 1
    private var pendingSave: DispatchWorkItem?

    var onTearBegan: (CGPoint) -> Void = { _ in }
    var onTearMoved: (CGPoint, TimeInterval) -> Void = { _, _ in }
    var onTearEnded: (CGPoint, TimeInterval) -> Void = { _, _ in }

    /// Sits just above the desktop icons and below every normal app window.
    private static let desktopLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)

    init(store: StateStore, model: PadModel) {
        self.store = store
        self.model = model
        window = PadWindow(size: PadView.windowSize(scale: model.scale))
        super.init()

        let host = PadHostingView(rootView: PadView(
            model: model,
            onResizeBegin: { [weak self] in self?.beginResize() },
            onResize: { [weak self] distance in self?.resize(byDragging: distance) },
            onTearBegan: { [weak self] p in self?.onTearBegan(p) },
            onTearMoved: { [weak self] p, t in self?.onTearMoved(p, t) },
            onTearEnded: { [weak self] p, t in self?.onTearEnded(p, t) }))
        host.onScaleBy = { [weak self] factor in
            guard let self else { return }
            setScale(self.model.scale * factor)
        }
        window.contentView = host
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

    var level: NSWindow.Level { store.state.keepOnTop ? .floating : Self.desktopLevel }

    func applyLevel() {
        window.level = level
    }

    /// The top sheet's rectangle in screen coordinates (AppKit, y up).
    var sheetScreenRect: CGRect {
        let s = model.scale, f = window.frame
        return CGRect(x: f.minX + PadView.margin * s,
                      y: f.maxY - (PadView.margin + PadView.gripHeight + PadView.sheetSize.height) * s,
                      width: PadView.sheetSize.width * s,
                      height: PadView.sheetSize.height * s)
    }

    // MARK: - Size

    var scale: CGFloat { model.scale }

    /// Resizes the pad, keeping its top-left corner (the nail it hangs from) in place.
    func setScale(_ newScale: CGFloat) {
        let s = min(max(newScale, Self.scaleRange.lowerBound), Self.scaleRange.upperBound)
        guard abs(s - model.scale) > 0.001 else { return }
        let old = window.frame
        let size = PadView.windowSize(scale: s)
        model.scale = s
        window.setFrame(CGRect(x: old.minX, y: old.maxY - size.height, width: size.width, height: size.height),
                        display: true)
        store.state.padScale = s
        if let display = displayKey(window.screen) {
            store.state.padScalesByDisplay[display] = s
        }
        scheduleSave()
    }

    private func beginResize() {
        scaleAtDragStart = model.scale
    }

    private func resize(byDragging distance: CGFloat) {
        let startWidth = PadView.sheetSize.width * scaleAtDragStart
        setScale(scaleAtDragStart * (startWidth + distance) / startWidth)
    }

    private func displayKey(_ screen: NSScreen?) -> String? {
        (screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue
    }

    func windowDidChangeScreen(_ notification: Notification) {
        if let display = displayKey(window.screen), let saved = store.state.padScalesByDisplay[display] {
            setScale(saved)
        }
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.store.save() }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    // MARK: - Positioning

    private func defaultOrigin() -> CGPoint {
        let visible = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        let size = window.frame.size
        return CGPoint(x: visible.maxX - size.width - 40, y: visible.maxY - size.height - 20)
    }

    /// True if at least the binding strip would be reachable on some display.
    private func isVisibleOnSomeScreen(origin: CGPoint) -> Bool {
        let s = model.scale
        let frame = CGRect(origin: origin, size: window.frame.size)
        let grip = CGRect(x: frame.minX + PadView.margin * s,
                          y: frame.maxY - (PadView.margin + PadView.gripHeight) * s,
                          width: PadView.sheetSize.width * s,
                          height: PadView.gripHeight * s)
        return NSScreen.screens.contains { $0.visibleFrame.intersection(grip).width > 60 }
    }

    @objc private func screensChanged() {
        if !isVisibleOnSomeScreen(origin: window.frame.origin) {
            resetPosition()
        }
    }

    func windowDidMove(_ notification: Notification) {
        store.state.padOrigin = window.frame.origin
        scheduleSave()
    }
}
