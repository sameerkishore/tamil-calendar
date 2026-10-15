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
    /// A ball went in.
    var onBinned: () -> Void = {}
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
        controller.onBinned = { [weak self] in
            self?.remove(record.id)
            self?.onBinned()
        }
        windows[record.id] = controller
        controller.window.orderFront(nil)
    }
}

@MainActor
@Observable
final class BallMotion {
    /// Extra roll picked up while flying and rolling, radians.
    var spin: CGFloat = 0
}

/// One paper ball: a small borderless window around the ball and its shadow. Drag it and let go
/// mid-motion to throw it; it flies under gravity, bounces off the bin's rim and sides, the screen
/// edges and the floor, and drops into the bin through the mouth.
@MainActor
final class PaperBallWindowController {
    let window: NSWindow
    var onRest: (CGPoint) -> Void = { _ in }
    var onBinned: () -> Void = {}
    var bin: () -> BinTarget? = { nil }
    var restingLevel: NSWindow.Level = .normal {
        didSet { if flight == nil { window.level = restingLevel } }
    }

    private let motion = BallMotion()
    private let scale: CGFloat
    private var flight: Timer?
    private var position: CGPoint = .zero
    private var velocity: CGVector = .zero
    private var screen: CGRect = .zero
    private var lastStep: TimeInterval = 0

    // Physics, in points and seconds (scaled with the ball).
    private var radius: CGFloat { 30 * scale }
    private var gravity: CGFloat { 2_200 * scale }
    /// Below this release speed the ball is just set down.
    private let throwThreshold: CGFloat = 400
    /// Share of the hand's speed the ball leaves with: a flick is quicker than the toss it makes.
    private let throwStrength: CGFloat = 0.45

    /// Window side, in points: ball plus room for lumps and shadow.
    static func side(scale: CGFloat) -> CGFloat {
        PadView.sheetSize.width * CrumpledSheet.ballSize * 1.3 * scale + 24 * scale
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
        host.onDragStarted = { [weak self] in self?.pickUp() }
        host.onDragEnded = { [weak self] v in self?.letGo(velocity: v) }
        host.onClick = { SoundPlayer.shared.play("rustle", volume: 0.4) }
        window.contentView = host
    }

    func close() {
        flight?.invalidate()
        window.orderOut(nil)
    }

    private var center: CGPoint { CGPoint(x: window.frame.midX, y: window.frame.midY) }

    private func pickUp() {
        flight?.invalidate()
        flight = nil
        // In hand, the ball is above other apps so you can see where you're aiming.
        window.level = max(restingLevel, .floating)
    }

    private func letGo(velocity v: CGVector) {
        // Dropped straight into the mouth.
        if let bin = bin(), !bin.isFull, bin.mouth.contains(center.x),
           center.y > bin.body.midY, center.y < bin.rimY + radius * 2 {
            dropIn(bin)
            return
        }
        let speed = hypot(v.dx, v.dy)
        if speed > throwThreshold {
            SoundPlayer.shared.play("whoosh", volume: Float(min(speed / 3_000, 1)) * 0.8)
            fly(from: center, velocity: CGVector(dx: v.dx * throwStrength, dy: v.dy * throwStrength))
        } else {
            window.level = restingLevel
            onRest(center)
        }
    }

    // MARK: - Flight

    private func fly(from start: CGPoint, velocity v: CGVector) {
        position = start
        // Cap silly speeds from a jerk of the mouse.
        let speed = hypot(v.dx, v.dy), cap = 1_900 * scale
        velocity = speed > cap ? CGVector(dx: v.dx / speed * cap, dy: v.dy / speed * cap) : v
        screen = (NSScreen.screens.first { $0.frame.contains(start) } ?? NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        lastStep = ProcessInfo.processInfo.systemUptime
        flight = Timer.scheduledTimer(withTimeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.step() }
        }
    }

    private func step() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(now - lastStep, 1.0 / 30)
        lastStep = now
        let r = radius
        let previous = position

        velocity.dy -= gravity * dt
        velocity.dx *= 1 - 0.6 * dt    // paper balls are light: noticeable air drag
        position.x += velocity.dx * dt
        position.y += velocity.dy * dt

        if let bin = bin(), handleBin(bin, previous: previous) { return }

        // Screen edges and the floor (the top of the Dock).
        var onFloor = false
        if position.x < screen.minX + r { position.x = screen.minX + r; velocity.dx = abs(velocity.dx) * 0.5 }
        if position.x > screen.maxX - r { position.x = screen.maxX - r; velocity.dx = -abs(velocity.dx) * 0.5 }
        if position.y > screen.maxY - r { position.y = screen.maxY - r; velocity.dy = -abs(velocity.dy) * 0.3 }
        if position.y < screen.minY + r {
            position.y = screen.minY + r
            if velocity.dy < -160 * scale {
                SoundPlayer.shared.play("rustle", volume: Float(min(-velocity.dy / (2_000 * scale), 1)) * 0.6)
                velocity.dy = -velocity.dy * 0.35
            } else {
                velocity.dy = 0
                onFloor = true
            }
            velocity.dx *= 0.82   // paper doesn't roll far
        }

        // Rolling spin: distance travelled over the radius.
        motion.spin += velocity.dx * dt / r
        window.setFrameOrigin(CGPoint(x: position.x - window.frame.width / 2, y: position.y - window.frame.height / 2))

        if onFloor && abs(velocity.dx) < 12 * scale {
            land()
        }
    }

    /// Rim, sides and mouth. Returns true if the ball went in.
    private func handleBin(_ bin: BinTarget, previous: CGPoint) -> Bool {
        let r = radius
        // Crossing the rim line on the way down.
        if previous.y >= bin.rimY && position.y < bin.rimY && velocity.dy < 0 {
            let inMouth = bin.mouth.contains(position.x)
            if inMouth && !bin.isFull {
                dropIn(bin)
                return true
            }
            // Just inside the rim: catch the edge and tip in, rather than bouncing out.
            let insideEdge = position.x > bin.body.minX && position.x < bin.body.maxX
            if insideEdge && !bin.isFull {
                SoundPlayer.shared.play("rim", volume: 0.5)
                dropIn(bin)
                return true
            }
            let nearBin = position.x > bin.body.minX - r * 0.7 && position.x < bin.body.maxX + r * 0.7
            if nearBin {
                // Clipped the rim (or landed on a full heap): bounce up and away from the middle.
                SoundPlayer.shared.play(bin.isFull ? "rustle" : "rim", volume: 0.7)
                position.y = bin.rimY + 1
                velocity.dy = abs(velocity.dy) * 0.45
                velocity.dx += (position.x < bin.body.midX ? -1 : 1) * 160 * scale
            }
        }
        // The outside walls.
        if position.y < bin.rimY && position.y > bin.body.minY - r {
            let edge = bin.halfWidth(at: position.y) + r * 0.8
            let dx = position.x - bin.body.midX
            if abs(dx) < edge && !(previous.y >= bin.rimY) {
                position.x = bin.body.midX + (dx < 0 ? -edge : edge)
                velocity.dx = (dx < 0 ? -1 : 1) * abs(velocity.dx) * 0.4
            }
        }
        return false
    }

    /// Falls in through the mouth and disappears into the heap.
    private func dropIn(_ bin: BinTarget) {
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
            MainActor.assumeIsolated { self?.onBinned() }
        })
    }

    private func land() {
        flight?.invalidate()
        flight = nil
        window.level = restingLevel
        onRest(center)
    }
}

struct PaperBallView: View {
    let record: PaperBallRecord
    let model: PadModel
    let motion: BallMotion
    let side: CGFloat

    var body: some View {
        let theme = model.theme(scale: record.scale)
        // Same drawing as the end of the crumple animation, so the hand-over is seamless.
        CrumpledSheet(context: record.context, layout: model.layout, tornFromLeft: record.tornFromLeft, t: 1)
            .rotationEffect(.radians(record.rotation + motion.spin))
            .shadow(color: .black.opacity(0.4), radius: theme.u(4), x: theme.u(1), y: theme.u(4))
            .frame(width: side, height: side)
            .environment(\.cardTheme, theme)
    }
}
