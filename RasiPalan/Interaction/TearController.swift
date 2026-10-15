import AppKit
import Observation
import RasiCore
import SwiftUI

/// The pose of the sheet being torn, in overlay coordinates (top-left origin, y down).
@MainActor
@Observable
final class TearState {
    let context: DayContext
    let layout: CardLayout
    let theme: CardTheme
    /// Top-left of the sheet when it hung on the pad.
    let origin: CGPoint
    let size: CGSize

    /// Fraction of the perforation torn, 0…1.
    var progress: CGFloat = 0
    var tearFromLeft = true
    /// Hinge on the top edge (sheet-local x) the sheet swings around while still attached.
    var hingeX: CGFloat = 0
    /// Clockwise radians about the hinge.
    var rotation: CGFloat = 0
    /// Bend, in sheet-local points (bottom edge displacement).
    var pull: CGSize = .zero
    /// Movement of the whole sheet once it's free.
    var translation: CGSize = .zero
    var isFree = false

    init(context: DayContext, layout: CardLayout, theme: CardTheme, origin: CGPoint, size: CGSize) {
        self.context = context
        self.layout = layout
        self.theme = theme
        self.origin = origin
        self.size = size
    }

    var hinge: CGPoint { CGPoint(x: origin.x + hingeX, y: origin.y) }

    /// Where a sheet-local point currently is in the overlay.
    func overlayPoint(local: CGPoint) -> CGPoint {
        let p = CGPoint(x: origin.x + local.x - hinge.x, y: origin.y + local.y - hinge.y)
        let c = cos(rotation), s = sin(rotation)
        return CGPoint(x: hinge.x + p.x * c - p.y * s + translation.width,
                       y: hinge.y + p.x * s + p.y * c + translation.height)
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

/// Runs one tear gesture: shows the sheet in a full-screen transparent overlay while it's being
/// pulled, breaks the perforation one hole at a time, and hands the free sheet over to become
/// a floating window.
///
/// Feel: paper barely stretches, so most of the pull becomes tension. Each hole needs a bit more
/// pull to give way, and holes always break one after another (a fast yank zips through them in
/// quick succession rather than skipping), each with a tick, a small snap and a haptic click.
@MainActor
final class TearController {
    /// The top sheet has been lifted: the pad should now show the next day underneath.
    var onLift: () -> Void = {}
    /// The tear was abandoned and the sheet is back on the pad.
    var onSettle: () -> Void = {}
    /// The sheet is fully off the pad (the pad should advance a day).
    var onTornOff: () -> Void = {}
    /// The user let go of a free sheet: make it a floating window.
    var onDrop: (TornSheet) -> Void = { _ in }
    /// Current feel settings, read at the start of each tear.
    var physics: () -> TearPhysics = { .defaults }

    private var p = TearPhysics.defaults
    private var overlay: NSWindow?
    private var state: TearState?
    private var overlayFrame: CGRect = .zero
    private var grab: CGPoint = .zero      // overlay coords at mouse-down
    private var grabLocal: CGPoint = .zero // sheet-local
    private var mouse: CGPoint = .zero     // overlay coords, latest
    private var broken = 0                 // perforation holes torn so far
    private var targetBroken = 0
    private var breakTimer: Timer?
    private var breakInterval: TimeInterval = 0.045
    private var dropWhenFree = false
    private var lastBreakTime: TimeInterval = 0

    private var isActive: Bool { state != nil }


    func begin(at screenPoint: CGPoint, sheetRect: CGRect, context: DayContext, layout: CardLayout,
               theme: CardTheme, level: NSWindow.Level) {
        guard !isActive else { return }
        p = physics()
        overlayFrame = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
        let origin = toOverlay(CGPoint(x: sheetRect.minX, y: sheetRect.maxY))
        let state = TearState(context: context, layout: layout, theme: theme, origin: origin, size: sheetRect.size)
        self.state = state
        grab = toOverlay(screenPoint)
        mouse = grab
        grabLocal = CGPoint(x: grab.x - origin.x, y: grab.y - origin.y)
        broken = 0
        targetBroken = 0
        breakInterval = p.breakInterval
        dropWhenFree = false

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
        guard let state else { return }
        mouse = toOverlay(screenPoint)

        if state.isFree {
            // In hand: the grabbed point follows the mouse.
            let held = state.overlayPoint(local: grabLocal)
            state.translation.width += mouse.x - held.x
            state.translation.height += mouse.y - held.y
            return
        }

        // Until the first hole goes, pull direction picks the side the tear starts from.
        let d = CGPoint(x: mouse.x - grab.x, y: mouse.y - grab.y)
        if broken == 0 {
            state.tearFromLeft = d.x >= 0
            state.hingeX = state.tearFromLeft ? state.size.width : 0
        }

        let s = state.theme.scale
        let pull = hypot(d.x, d.y)
        let tension = (pull - p.firstHolePull * s) / (p.tearLength * s)
        let target = tension < 0 ? 0 : min(p.holes, 1 + Int(tension * CGFloat(p.holes - 1)))
        if target > targetBroken {
            targetBroken = target
            scheduleBreaks()
        }
        updatePose()
    }

    func end(at screenPoint: CGPoint, time: TimeInterval) {
        guard let state else { return }
        SoundPlayer.shared.setTearIntensity(0)

        if state.isFree {
            drop()
        } else if broken * 2 >= p.holes {
            // Past halfway: zip through the remaining holes, then let it fall free where it is.
            dropWhenFree = true
            targetBroken = p.holes
            breakInterval = p.breakInterval / 2
            scheduleBreaks()
        } else {
            breakTimer?.invalidate()
            breakTimer = nil
            SoundPlayer.shared.stopTearing()
            if broken > 0 || hypot(state.pull.width, state.pull.height) > 2 {
                SoundPlayer.shared.play("rustle", volume: 0.8)
            }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) {
                state.progress = 0
                state.rotation = 0
                state.pull = .zero
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.onSettle()
                self?.finish()
            }
        }
    }

    // MARK: - Perforations

    /// Breaks holes one at a time until `targetBroken`, never faster than `breakInterval` apart.
    private func scheduleBreaks() {
        guard breakTimer == nil else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastBreakTime >= breakInterval { breakNextHole() }
        guard broken < targetBroken else { return }
        breakTimer = Timer.scheduledTimer(withTimeInterval: breakInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                guard self.broken < self.targetBroken, self.state != nil else {
                    self.breakTimer?.invalidate()
                    self.breakTimer = nil
                    return
                }
                self.breakNextHole()
            }
        }
    }

    private func breakNextHole() {
        guard let state, broken < targetBroken else { return }
        broken += 1
        lastBreakTime = ProcessInfo.processInfo.systemUptime

        if broken == 1 { SoundPlayer.shared.startTearing() }
        SoundPlayer.shared.play("perf", volume: Float.random(in: 0.55...0.95), pitchJitter: 0.15)
        SoundPlayer.shared.setTearIntensity(0.35)
        if p.haptics {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }

        // Each hole gives with a small snap: the sheet jumps a little further into its swing.
        withAnimation(.spring(response: 0.14, dampingFraction: 0.5)) {
            state.progress = CGFloat(broken) / CGFloat(p.holes)
            updatePose()
        }

        if broken >= p.holes {
            breakTimer?.invalidate()
            breakTimer = nil
            tearOff()
            if dropWhenFree { drop() }
        }
    }

    /// Swing and bend for the current mouse position and tear progress.
    private func updatePose() {
        guard let state, !state.isFree else { return }
        let s = state.theme.scale

        // Swing about the hinge so the grabbed point heads towards the mouse; the more holes
        // have gone, the freer the sheet is to swing.
        let hinge = state.hinge
        let from = atan2(grab.y - hinge.y, grab.x - hinge.x)
        let to = atan2(mouse.y - hinge.y, mouse.x - hinge.x)
        var angle = to - from
        if angle > .pi { angle -= 2 * .pi }
        if angle < -.pi { angle += 2 * .pi }
        let freedom = smoothstep(state.progress)
        state.rotation = max(-p.maxSwing, min(p.maxSwing, angle * freedom))

        // The rest is tension: paper gives only a few points, rubber-banded hard.
        let held = state.overlayPoint(local: grabLocal)
        let rest = CGPoint(x: mouse.x - held.x, y: mouse.y - held.y)
        let c = cos(-state.rotation), sn = sin(-state.rotation)
        let local = CGPoint(x: rest.x * c - rest.y * sn, y: rest.x * sn + rest.y * c)
        let len = hypot(local.x, local.y)
        let limit = p.maxBend * s
        let bent = len > 0 ? limit * tanh(len / (limit * 6)) / len : 0
        state.pull = CGSize(width: local.x * bent, height: local.y * bent)
    }

    private func tearOff() {
        guard let state, !state.isFree else { return }
        SoundPlayer.shared.stopTearing()
        SoundPlayer.shared.play("rip", volume: 0.55)
        state.progress = 1
        state.isFree = true
        // Paper relaxes once it's free, and the grabbed point catches up with the hand.
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            state.pull = .zero
            if !dropWhenFree {
                let held = state.overlayPoint(local: grabLocal)
                state.translation.width += mouse.x - held.x
                state.translation.height += mouse.y - held.y
            }
        }
        onTornOff()
    }

    private func drop() {
        guard let state else { return }
        let local = CGPoint(x: state.size.width / 2, y: state.size.height / 2)
        let c = state.overlayPoint(local: local)
        onDrop(TornSheet(context: state.context,
                         center: CGPoint(x: overlayFrame.minX + c.x, y: overlayFrame.maxY - c.y),
                         rotation: state.rotation,
                         scale: state.theme.scale,
                         tornFromLeft: state.tearFromLeft))
        // Let the floating window appear before the overlay copy disappears.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in self?.finish() }
    }

    private func finish() {
        breakTimer?.invalidate()
        breakTimer = nil
        overlay?.orderOut(nil)
        overlay = nil
        state = nil
    }

    private func toOverlay(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x - overlayFrame.minX, y: overlayFrame.maxY - p.y)
    }

    private func smoothstep(_ x: CGFloat) -> CGFloat {
        let t = min(max(x / 0.4, 0), 1)
        return t * t * (3 - 2 * t)
    }
}

/// Draws the sheet being torn at its current pose.
struct TearOverlayView: View {
    let state: TearState
    @Environment(\.cardTheme) private var theme

    var body: some View {
        let inset = theme.u(20)
        let padded = CGSize(width: state.size.width + inset * 2, height: state.size.height + inset * 2)
        let lift = min(1, 0.3 * hypot(state.pull.width, state.pull.height) / theme.u(6) + state.progress * 0.6
                       + (state.isFree ? 0.3 : 0))

        ZStack(alignment: .topLeading) {
            Color.clear
            SheetFace(context: state.context, layout: state.layout,
                      torn: state.progress, tornFromLeft: state.tearFromLeft)
                // Paper lifting off the pad catches less light towards the free end.
                .overlay(LinearGradient(colors: [.clear, .black.opacity(0.10 * lift)], startPoint: .top, endPoint: .bottom))
                .padding(inset)
                .distortionEffect(
                    ShaderLibrary.paperPull(.float2(state.size), .float2(state.pull), .float(inset)),
                    maxSampleOffset: CGSize(width: inset, height: inset))
                .rotationEffect(.radians(state.rotation),
                                anchor: UnitPoint(x: (inset + state.hingeX) / padded.width, y: inset / padded.height))
                .shadow(color: .black.opacity(0.18 + 0.2 * lift), radius: theme.u(4 + 14 * lift),
                        x: theme.u(2 * lift), y: theme.u(3 + 10 * lift))
                .offset(x: state.origin.x - inset + state.translation.width,
                        y: state.origin.y - inset + state.translation.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
