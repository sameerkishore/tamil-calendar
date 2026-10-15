import AppKit
import Observation
import RasiCore
import SwiftUI

/// The sheet being torn, in overlay coordinates (top-left origin, y down).
@MainActor
@Observable
final class TearState {
    let context: DayContext
    let layout: CardLayout
    let theme: CardTheme
    /// Top-left of the sheet when it hung on the pad.
    let origin: CGPoint
    let size: CGSize

    /// How far the perforation has torn, left to right, 0…1.
    var progress: CGFloat = 0
    /// How far the bottom-left corner has been lifted, folding the page over (sheet-local).
    var fold: CGSize = .zero
    /// Once it's off: drift and tilt as it drops.
    var translation: CGSize = .zero
    var rotation: CGFloat = 0
    var isFree = false

    init(context: DayContext, layout: CardLayout, theme: CardTheme, origin: CGPoint, size: CGSize) {
        self.context = context
        self.layout = layout
        self.theme = theme
        self.origin = origin
        self.size = size
    }
}

/// A sheet that has come off the pad, ready to become a floating window.
struct TornSheet {
    var context: DayContext
    /// Centre of the sheet in screen coordinates (AppKit, y up).
    var center: CGPoint
    /// Clockwise radians.
    var rotation: CGFloat
    var scale: CGFloat
    var tornFromLeft: Bool
}

/// One tear: drag across the sheet and it folds like a book page held by its bottom-left
/// corner while the perforation tears left to right in step with the drag. Far enough across
/// and it comes off, unfolds and drops onto the desktop.
@MainActor
final class TearController {
    /// The top sheet has been lifted: the pad should now show the next day underneath.
    var onLift: () -> Void = {}
    /// The tear was abandoned and the sheet is back on the pad.
    var onSettle: () -> Void = {}
    /// The sheet is off the pad (the pad should advance a day).
    var onTornOff: () -> Void = {}
    /// The sheet has landed: make it a floating window.
    var onDrop: (TornSheet) -> Void = { _ in }
    /// Current feel settings, read at the start of each tear.
    var physics: () -> TearPhysics = { .defaults }

    private var p = TearPhysics.defaults
    private var overlay: NSWindow?
    private var state: TearState?
    private var overlayFrame: CGRect = .zero
    private var grab: CGPoint = .zero

    /// Let go past this much and the tear finishes by itself.
    private let finishOnRelease: CGFloat = 0.6

    func begin(at screenPoint: CGPoint, sheetRect: CGRect, context: DayContext, layout: CardLayout,
               theme: CardTheme, level: NSWindow.Level) {
        guard state == nil else { return }
        p = physics()
        overlayFrame = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
        let origin = toOverlay(CGPoint(x: sheetRect.minX, y: sheetRect.maxY))
        let state = TearState(context: context, layout: layout, theme: theme, origin: origin, size: sheetRect.size)
        self.state = state
        grab = toOverlay(screenPoint)

        let window = NSWindow(contentRect: overlayFrame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        // In hand, the sheet stays above other apps even when the pad lives on the desktop.
        window.level = max(level, .floating)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.contentView = NSHostingView(rootView: TearOverlayView(state: state).environment(\.cardTheme, theme))
        window.setFrame(overlayFrame, display: true)
        window.orderFront(nil)
        overlay = window

        // Swap only once the overlay is on screen, so there's no flash of the next day.
        DispatchQueue.main.async { [weak self] in self?.onLift() }
    }

    func move(to screenPoint: CGPoint, time: TimeInterval) {
        guard let state, !state.isFree else { return }
        let mouse = toOverlay(screenPoint)
        let w = state.size.width, h = state.size.height

        // The corner follows the hand, within what a page can physically fold to.
        let dx = min(max(mouse.x - grab.x, -0.1 * w), 1.5 * w)
        let dy = min(max(mouse.y - grab.y, -1.1 * h), 0.1 * h)
        state.fold = CGSize(width: dx, height: dy)

        // The perforation tears left to right as you drag across; torn paper stays torn.
        let progress = min(max(dx / (w * p.dragAcross), 0), 1)
        if progress > state.progress {
            if state.progress == 0 { SoundPlayer.shared.startTearing() }
            SoundPlayer.shared.setTearIntensity(Double(progress - state.progress) * 30)
            state.progress = progress
        }
        if state.progress >= 1 { tearOff() }
    }

    func end(at screenPoint: CGPoint, time: TimeInterval) {
        guard let state, !state.isFree else { return }
        if state.progress >= finishOnRelease {
            tearOff()
        } else {
            SoundPlayer.shared.stopTearing()
            if state.progress > 0 { SoundPlayer.shared.play("rustle", volume: 0.7) }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                state.fold = .zero
                state.progress = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.onSettle()
                self?.finish()
            }
        }
    }

    /// The last of the perforation goes: the page unfolds and drops a little onto the desktop.
    private func tearOff() {
        guard let state, !state.isFree else { return }
        state.isFree = true
        SoundPlayer.shared.stopTearing()
        SoundPlayer.shared.play("rip", volume: 0.7)
        if p.haptics { NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now) }
        onTornOff()

        let s = state.theme.scale
        withAnimation(.easeIn(duration: 0.12)) { state.progress = 1 }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            state.fold = .zero
            state.translation = CGSize(width: 18 * s, height: 46 * s)
            state.rotation = CGFloat.random(in: 0.06...0.16) * (Bool.random() ? 1 : -1)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.drop() }
    }

    private func drop() {
        guard let state else { return }
        let c = CGPoint(x: state.origin.x + state.size.width / 2 + state.translation.width,
                        y: state.origin.y + state.size.height / 2 + state.translation.height)
        onDrop(TornSheet(context: state.context,
                         center: CGPoint(x: overlayFrame.minX + c.x, y: overlayFrame.maxY - c.y),
                         rotation: state.rotation,
                         scale: state.theme.scale,
                         tornFromLeft: true))
        // Let the floating window appear before the overlay copy disappears.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in self?.finish() }
    }

    private func finish() {
        overlay?.orderOut(nil)
        overlay = nil
        state = nil
    }

    private func toOverlay(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x - overlayFrame.minX, y: overlayFrame.maxY - p.y)
    }
}

/// Draws the sheet being torn: flat part, plus the folded-over corner.
struct TearOverlayView: View {
    let state: TearState

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            FoldedSheet(context: state.context, layout: state.layout, size: state.size,
                        fold: state.fold, torn: state.progress)
                .rotationEffect(.radians(state.rotation))
                .shadow(color: .black.opacity(state.isFree ? 0.3 : 0.15), radius: state.isFree ? 8 : 3,
                        y: state.isFree ? 5 : 2)
                .offset(x: state.origin.x + state.translation.width, y: state.origin.y + state.translation.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// A sheet with its bottom-left corner lifted by `fold` and folded over like a book page.
/// The fold line is the perpendicular bisector between where the corner was and where it is now;
/// everything on the corner's side of it is reflected across, showing the back of the paper.
struct FoldedSheet: View {
    let context: DayContext
    let layout: CardLayout
    let size: CGSize
    var fold: CGSize
    var torn: CGFloat

    var body: some View {
        let face = SheetFace(context: context, layout: layout, torn: torn, tornFromLeft: true)
        let corner = CGPoint(x: 0, y: size.height)
        let len = hypot(fold.width, fold.height)
        ZStack(alignment: .topLeading) {
            if len < 0.5 {
                face
            } else {
                let n = CGPoint(x: fold.width / len, y: fold.height / len)
                let mid = CGPoint(x: corner.x + fold.width / 2, y: corner.y + fold.height / 2)
                let rect = [CGPoint.zero, CGPoint(x: size.width, y: 0),
                            CGPoint(x: size.width, y: size.height), CGPoint(x: 0, y: size.height)]
                let side: (CGPoint) -> CGFloat = { ($0.x - mid.x) * n.x + ($0.y - mid.y) * n.y }

                // The part still lying flat on the pad.
                face.clipShape(Polygon(points: Self.clip(rect, keep: { side($0) >= 0 })))

                // The folded flap: the back of the sheet, print faintly showing through
                // (the reflection mirrors it, as it should be), darker towards the crease.
                face
                    .overlay(Ink.paper.opacity(0.86))
                    .overlay(
                        LinearGradient(colors: [.black.opacity(0.14), .clear],
                                       startPoint: UnitPoint(x: mid.x / size.width, y: mid.y / size.height),
                                       endPoint: UnitPoint(x: corner.x / size.width, y: corner.y / size.height)))
                    .clipShape(Polygon(points: Self.clip(rect, keep: { side($0) < 0 })))
                    .transformEffect(Self.reflection(across: mid, normal: n))
                    .shadow(color: .black.opacity(0.28), radius: 5, x: n.x * 3, y: n.y * 3)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    /// Mirror image across the line through `p` perpendicular to `normal`.
    static func reflection(across p: CGPoint, normal n: CGPoint) -> CGAffineTransform {
        // R = I − 2nnᵀ, applied about p.
        let a = 1 - 2 * n.x * n.x, b = -2 * n.x * n.y, d = 1 - 2 * n.y * n.y
        return CGAffineTransform(a: a, b: b, c: b, d: d,
                                 tx: p.x - (a * p.x + b * p.y), ty: p.y - (b * p.x + d * p.y))
    }

    /// Clips a convex polygon to the half-plane where `keep` is true (Sutherland–Hodgman).
    static func clip(_ poly: [CGPoint], keep: (CGPoint) -> Bool) -> [CGPoint] {
        var out: [CGPoint] = []
        for i in poly.indices {
            let a = poly[i], b = poly[(i + 1) % poly.count]
            let ka = keep(a), kb = keep(b)
            if ka { out.append(a) }
            if ka != kb {
                // Find the crossing by bisection: exact enough and free of special cases.
                var lo = a, hi = b
                for _ in 0..<20 {
                    let m = CGPoint(x: (lo.x + hi.x) / 2, y: (lo.y + hi.y) / 2)
                    if keep(m) == ka { lo = m } else { hi = m }
                }
                out.append(lo)
            }
        }
        return out
    }
}

struct Polygon: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        points.dropFirst().forEach { path.addLine(to: $0) }
        path.closeSubpath()
        return path
    }
}
