import AppKit

/// Keeps desktop objects reachable when displays are unplugged or rearranged.
@MainActor
enum ScreenFit {
    /// If `window` is mostly off every screen, moves it onto the main screen. Returns true if moved.
    @discardableResult
    static func bringOnScreen(_ window: NSWindow) -> Bool {
        let f = window.frame
        let visible = NSScreen.screens.map { $0.visibleFrame.intersection(f) }
            .reduce(0) { $0 + ($1.isNull ? 0 : $1.width * $1.height) }
        guard visible < f.width * f.height * 0.4, let screen = NSScreen.main ?? NSScreen.screens.first else { return false }
        let vf = screen.visibleFrame
        let x = min(max(f.minX, vf.minX), vf.maxX - f.width)
        let y = min(max(f.minY, vf.minY), vf.maxY - f.height)
        window.setFrameOrigin(CGPoint(x: x, y: y))
        return true
    }
}
