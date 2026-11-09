import AppKit
import Observation
import RasiCore
import SwiftUI

/// A crumpled sheet lying on the desktop. Keeps the sheet's data so the ball shows that day's print.
struct PaperBallRecord: Codable, Identifiable {
    var id = UUID()
    var day: CalendarDay
    var location: GeoLocation
    var style: PanchangamStyle
    var tornFromLeft: Bool
    /// Centre in screen coordinates (AppKit, y up).
    var center: CGPoint
    /// Clockwise radians.
    var rotation: CGFloat
    var scale: CGFloat

    init(sheet: FloatingSheetRecord) {
        day = sheet.day
        location = sheet.location
        style = sheet.style
        tornFromLeft = sheet.tornFromLeft
        center = sheet.center
        rotation = sheet.rotation
        scale = sheet.scale
    }

    var context: DayContext { DayContext(day: day, location: location, style: style) }
}

/// Owns every paper ball window, and tells the bin when one lands in it.
@MainActor
final class PaperBallsController {
    private let store: StateStore
    private let model: PadModel
    private var windows: [UUID: PaperBallWindowController] = [:]
    /// The bin to aim at (nil while it's hidden).
    var bin: () -> BinTarget? = { nil }
    /// A ball went in, this hard (0…1).
    var onBinned: (CGFloat) -> Void = { _ in }
    /// Balls appeared or disappeared (the bin shows while there are any).
    var onCountChanged: () -> Void = {}
    var level: () -> NSWindow.Level = { .normal }

    var isEmpty: Bool { store.state.paperBalls.isEmpty }

    init(store: StateStore, model: PadModel) {
        self.store = store
        self.model = model
    }

    func restore() {
        for record in store.state.paperBalls {
            open(record)
        }
    }

    func add(_ record: PaperBallRecord) {
        store.state.paperBalls.append(record)
        store.save()
        open(record)
        onCountChanged()
    }

    func remove(_ id: UUID) {
        windows.removeValue(forKey: id)?.close()
        store.state.paperBalls.removeAll { $0.id == id }
        store.save()
        onCountChanged()
    }

    /// Sweeps every one away with a quick fade.
    func removeAll() {
        for (_, controller) in windows {
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.25; controller.window.animator().alphaValue = 0 },
                                                 completionHandler: { MainActor.assumeIsolated { controller.close() } })
        }
        windows.removeAll()
        store.state.paperBalls.removeAll()
        store.save()
        onCountChanged()
    }

    /// After a display change: anything stranded off-screen comes back.
    func bringOnScreen() {
        for (id, controller) in windows where ScreenFit.bringOnScreen(controller.window) {
            if let i = store.state.paperBalls.firstIndex(where: { $0.id == id }) {
                store.state.paperBalls[i].center = CGPoint(x: controller.window.frame.midX, y: controller.window.frame.midY)
            }
        }
        store.save()
    }

    /// The pull-back setting changed.
    func refreshTabs() {
        windows.values.forEach { $0.refreshTab() }
    }

    func setLevel(_ level: NSWindow.Level) {
        windows.values.forEach { $0.restingLevel = level }
    }

    private func open(_ record: PaperBallRecord) {
        let controller = PaperBallWindowController(record: record, model: model)
        controller.restingLevel = level()
        controller.bin = { [weak self] in self?.bin() }
        controller.onRest = { [weak self] center in
            guard let self, let i = store.state.paperBalls.firstIndex(where: { $0.id == record.id }) else { return }
            store.state.paperBalls[i].center = center
            store.save()
        }
        controller.usesPullBack = { [weak self] in self?.store.state.pullBackToThrow ?? false }
        controller.onBinned = { [weak self] power in
            self?.remove(record.id)
            self?.onBinned(power)
        }
        controller.refreshTab()
        windows[record.id] = controller
        controller.window.orderFront(nil)
    }
}

@MainActor
@Observable
final class BallMotion {
    /// Extra roll picked up while flying and rolling, radians.
    var spin: CGFloat = 0
    /// The pull tab is sticking out of it.
    var showsTab = false
}

/// One paper ball: a small borderless window around the ball and its shadow. Drag it and let go
/// mid-motion to throw it (or, if pull-back is chosen in Settings, drag it to place it and pull its tab to throw); it flies under gravity, bounces off the bin's rim and sides, the screen
/// edges and the floor, and drops into the bin through the mouth.
@MainActor
final class PaperBallWindowController {
    let window: NSWindow
    var onRest: (CGPoint) -> Void = { _ in }
    /// Went in, this hard (0…1).
    var onBinned: (CGFloat) -> Void = { _ in }
    var bin: () -> BinTarget? = { nil }
    /// Dragging pulls back to aim, instead of carrying the ball and flicking it.
    var usesPullBack: () -> Bool = { false }
    var restingLevel: NSWindow.Level = .normal {
        didSet { if flight == nil { window.level = restingLevel } }
    }

    private let motion = BallMotion()
    private let scale: CGFloat
    private var flight: Timer?
    private var ball: BallFlight?
    private var lastStep: TimeInterval = 0
    private var unsimulated: TimeInterval = 0
    private var aim: Aim?
    private var grabbedAt: (() -> CGPoint)?

    /// A pull in progress.
    private struct Aim {
        /// Where the hand took hold, and where the ball and its tab were then.
        let grab: CGPoint
        let anchor: CGPoint
        let tab: CGPoint
        let screen: NSScreen
        let overlay: BallAimOverlay

        /// Keeps the tab where it was under the hand, wherever on it the hand took hold.
        func pull(hand: CGPoint) -> BallPull {
            BallPull(ball: anchor, hand: CGPoint(x: tab.x + hand.x - grab.x, y: tab.y + hand.y - grab.y),
                     slack: hypot(tab.x - anchor.x, tab.y - anchor.y), display: screen.frame)
        }
    }

    private var radius: CGFloat { 30 * scale }
    /// Below this release speed the ball is just set down.
    private let throwThreshold: CGFloat = 400
    /// Share of the hand's speed the ball leaves with: a flick is quicker than the toss it makes.
    private let throwStrength: CGFloat = 0.45

    /// Window side, in points: ball plus room for lumps and shadow.
    static func side(scale: CGFloat) -> CGFloat {
        let ball = PadView.sheetSize.width * CrumpledSheet.ballSize * 1.3 * scale + 24 * scale
        let tab = BallPullTab.offset(forBall: scale).dy + BallPullTab.size.height * BallPullTab.scale(forBall: scale)
        return max(ball, tab * 2)
    }

    init(record: PaperBallRecord, model: PadModel) {
        scale = record.scale
        let side = Self.side(scale: record.scale)
        window = NSWindow(contentRect: CGRect(x: record.center.x - side / 2, y: record.center.y - side / 2,
                                              width: side, height: side),
                          styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let host = DraggableHostingView(rootView: PaperBallView(record: record, model: model, motion: motion, side: side))
        grabbedAt = { [weak host] in host?.dragStart ?? .zero }
        host.onDragStarted = { [weak self] in self?.pickUp() }
        host.onDragMoved = { [weak self] hand in self?.moveAim(to: hand) }
        host.movesWindow = { [weak self] in self?.aim == nil }
        host.onDragEnded = { [weak self] v in self?.letGo(velocity: v) }
        host.onClick = { SoundPlayer.shared.play("rustle", volume: 0.4) }
        window.contentView = host
    }

    func close() {
        flight?.invalidate()
        aim?.overlay.close()
        aim = nil
        window.orderOut(nil)
    }

    private var center: CGPoint { CGPoint(x: window.frame.midX, y: window.frame.midY) }

    private func pickUp() {
        let tabWasOut = motion.showsTab
        flight?.invalidate()
        flight = nil
        // In hand, the ball is above other apps so you can see where you're aiming.
        window.level = max(restingLevel, .floating)
        if tabWasOut, let grab = grabbedAt?(), isOnTab(grab) { beginAim(grab: grab) }
        refreshTab()
    }

    /// The tab sticks out of a ball that's waiting to be pulled, not one flying or mid-pull.
    func refreshTab() {
        motion.showsTab = usesPullBack() && flight == nil && aim == nil
    }

    private func letGo(velocity v: CGVector) {
        if let aim {
            release(aim)
            return
        }
        // Dropped straight into the mouth.
        if let bin = bin(), !bin.isFull, bin.mouth.contains(center.x),
           center.y > bin.body.midY, center.y < bin.rimY + radius * 2 {
            dropIn(bin, power: 0)
            return
        }
        let speed = hypot(v.dx, v.dy)
        // With the tab to throw with, dragging the ball itself just puts it somewhere.
        if speed > throwThreshold && !usesPullBack() {
            SoundPlayer.shared.play("whoosh", volume: Float(min(speed / 3_000, 1)) * 0.8)
            let on = NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main ?? NSScreen.screens[0]
            fly(BallFlight(from: center, velocity: CGVector(dx: v.dx * throwStrength, dy: v.dy * throwStrength),
                           scale: scale, screen: on.visibleFrame))
        } else {
            window.level = restingLevel
            onRest(center)
        }
    }

    // MARK: - Aiming

    private var tabCenter: CGPoint {
        let offset = BallPullTab.offset(forBall: scale)
        return CGPoint(x: center.x + offset.dx, y: center.y + offset.dy)
    }

    /// Is this screen point on the visible part of the pull tab?
    private func isOnTab(_ p: CGPoint) -> Bool {
        let s = BallPullTab.scale(forBall: scale), reach: CGFloat = 5
        let tab = tabCenter
        return abs(p.x - tab.x) <= BallPullTab.size.width * s / 2 + reach
            && abs(p.y - tab.y) <= BallPullTab.size.height * s / 2 + reach
            && hypot(p.x - center.x, p.y - center.y) > 36 * scale
    }

    private func beginAim(grab: CGPoint) {
        let on = NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main ?? NSScreen.screens[0]
        aim = Aim(grab: grab, anchor: center, tab: tabCenter, screen: on,
                  overlay: BallAimOverlay(display: on.frame, under: window))
    }

    private func moveAim(to hand: CGPoint) {
        guard let aim else { return }
        let pull = aim.pull(hand: hand)
        // The ball leans a little towards the hand; the ribbon does the rest of the stretching.
        let lean = CGVector(dx: -pull.vector.dx * 28 * scale / BallPull.maxLength,
                            dy: -pull.vector.dy * 28 * scale / BallPull.maxLength)
        let usable = aim.screen.visibleFrame.insetBy(dx: radius, dy: radius)
        let ball = CGPoint(x: min(max(aim.anchor.x + lean.dx, usable.minX), usable.maxX),
                           y: min(max(aim.anchor.y + lean.dy, usable.minY), usable.maxY))
        moveWindow(to: ball)

        let path = pull.launches
            ? flight(from: ball, pull: pull, screen: aim.screen).opening(length: radius * 1.5 + BallAimDrawing.hintLength)
            : []
        // The ball leans along the same line, so the ribbon runs straight out of its centre.
        aim.overlay.show(ball: ball, hand: CGPoint(x: aim.anchor.x + pull.reach.dx, y: aim.anchor.y + pull.reach.dy),
                         path: path, power: pull.power, ballRadius: radius, tabScale: BallPullTab.scale(forBall: scale))
    }

    private func release(_ aim: Aim) {
        self.aim = nil
        aim.overlay.close()
        let pull = aim.pull(hand: NSEvent.mouseLocation)
        if pull.launches {
            SoundPlayer.shared.play("whoosh", volume: Float(pull.power) * 0.8)
            fly(flight(from: center, pull: pull, screen: aim.screen))
        } else {
            // Not pulled far enough to be a throw: it settles back where it was.
            moveWindow(to: aim.anchor)
            window.level = restingLevel
            onRest(aim.anchor)
            refreshTab()
        }
    }

    private func flight(from start: CGPoint, pull: BallPull, screen: NSScreen) -> BallFlight {
        BallFlight(from: start, velocity: BallFlight.launch(for: pull, scale: scale), scale: scale,
                   screen: screen.visibleFrame)
    }

    // MARK: - Flight

    private func fly(_ flight: BallFlight) {
        ball = flight
        unsimulated = 0
        lastStep = ProcessInfo.processInfo.systemUptime
        self.flight = Timer.scheduledTimer(withTimeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        refreshTab()
    }

    private func tick() {
        guard var ball else { return }
        defer { self.ball = ball }
        let now = ProcessInfo.processInfo.systemUptime
        unsimulated += min(now - lastStep, 1.0 / 30)
        lastStep = now
        let target = bin()

        while unsimulated >= BallFlight.stepTime {
            unsimulated -= BallFlight.stepTime
            switch ball.step(bin: target) {
            case .none:
                break
            case let .binned(bin, clippedRim):
                if clippedRim { SoundPlayer.shared.play("rim", volume: 0.5) }
                dropIn(bin, power: usesPullBack() ? ball.power : 0)
                return
            case let .rim(full):
                SoundPlayer.shared.play(full ? "rustle" : "rim", volume: 0.7)
            case let .floor(speed):
                SoundPlayer.shared.play("rustle", volume: Float(min(speed / (2_000 * scale), 1)) * 0.6)
            case .settled:
                moveWindow(to: ball.position)
                land()
                return
            }
            // Rolling spin: distance travelled over the radius.
            motion.spin += ball.velocity.dx * CGFloat(BallFlight.stepTime) / ball.radius
        }
        moveWindow(to: ball.position)
    }

    private func moveWindow(to point: CGPoint) {
        window.setFrameOrigin(CGPoint(x: point.x - window.frame.width / 2, y: point.y - window.frame.height / 2))
    }

    /// Falls in through the mouth and disappears into the heap.
    private func dropIn(_ bin: BinTarget, power: CGFloat) {
        flight?.invalidate()
        flight = nil
        let target = CGPoint(x: min(max(center.x, bin.mouth.lowerBound), bin.mouth.upperBound),
                             y: bin.rimY - radius * 0.6)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().setFrameOrigin(CGPoint(x: target.x - window.frame.width / 2,
                                                     y: target.y - window.frame.height / 2))
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated { self?.onBinned(power) }
        })
    }

    private func land() {
        flight?.invalidate()
        flight = nil
        window.level = restingLevel
        onRest(center)
        refreshTab()
    }
}

/// The tab where it waits, poking out from behind the ball.
struct TuckedPullTab: View {
    let ballScale: CGFloat

    var body: some View {
        let offset = BallPullTab.offset(forBall: ballScale)
        BallPullTab(scale: BallPullTab.scale(forBall: ballScale))
            .rotationEffect(.degrees(7))
            .offset(x: offset.dx, y: -offset.dy)
    }
}

struct PaperBallView: View {
    let record: PaperBallRecord
    let model: PadModel
    let motion: BallMotion
    let side: CGFloat

    var body: some View {
        let theme = model.theme(scale: record.scale)
        ZStack {
            if motion.showsTab { TuckedPullTab(ballScale: record.scale) }
            // Same drawing as the end of the crumple animation, so the hand-over is seamless.
            CrumpledSheet(context: record.context, layout: model.layout, tornFromLeft: record.tornFromLeft, t: 1)
                .rotationEffect(.radians(record.rotation + motion.spin))
                .shadow(color: .black.opacity(0.4), radius: theme.u(4), x: theme.u(1), y: theme.u(4))
        }
        .frame(width: side, height: side)
        .environment(\.cardTheme, theme)
    }
}
