import AppKit
import Observation
import RasiCore
import SwiftUI

/// A torn-off sheet lying on the desktop. Saved so it's still there after a relaunch.
struct FloatingSheetRecord: Codable, Identifiable {
    var id = UUID()
    var day: CalendarDay
    var location: GeoLocation
    var style: PanchangamStyle
    /// Centre in screen coordinates (AppKit, y up).
    var center: CGPoint
    /// Clockwise radians.
    var rotation: CGFloat
    var scale: CGFloat
    var tornFromLeft: Bool = true
    /// Reminders, events and weather as printed when the sheet was torn off.
    var extras: DayExtras?
    /// How worn it was when torn off (see `SheetFace.wear`).
    var wear: Float?

    var context: DayContext { DayContext(day: day, location: location, style: style) }
}

/// Owns every floating sheet window.
@MainActor
final class FloatingSheetsController {
    private let store: StateStore
    private let model: PadModel
    private var windows: [UUID: FloatingSheetWindowController] = [:]
    /// A sheet finished crumpling: it's now a ball at this centre, at this angle.
    var onCrumpled: (FloatingSheetRecord, CGFloat) -> Void = { _, _ in }

    init(store: StateStore, model: PadModel) {
        self.store = store
        self.model = model
    }

    func restore(level: NSWindow.Level) {
        for record in store.state.floatingSheets {
            open(record, level: level)
        }
    }

    func add(_ sheet: TornSheet, level: NSWindow.Level) {
        let record = FloatingSheetRecord(day: sheet.context.day, location: sheet.context.location,
                                         style: sheet.context.style, center: sheet.center,
                                         rotation: sheet.rotation, scale: sheet.scale,
                                         tornFromLeft: sheet.tornFromLeft, extras: sheet.extras,
                                         wear: sheet.wear > 0 ? sheet.wear : nil)
        store.state.floatingSheets.append(record)
        store.save()
        open(record, level: level)
    }

    func remove(_ id: UUID) {
        windows.removeValue(forKey: id)?.close()
        store.state.floatingSheets.removeAll { $0.id == id }
        store.save()
    }

    /// Sweeps every one away with a quick fade.
    func removeAll() {
        for (_, controller) in windows {
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.25; controller.window.animator().alphaValue = 0 },
                                                 completionHandler: { MainActor.assumeIsolated { controller.close() } })
        }
        windows.removeAll()
        store.state.floatingSheets.removeAll()
        store.save()
    }

    /// After a display change: anything stranded off-screen comes back.
    func bringOnScreen() {
        for (id, controller) in windows where ScreenFit.bringOnScreen(controller.window) {
            if let i = store.state.floatingSheets.firstIndex(where: { $0.id == id }) {
                store.state.floatingSheets[i].center = CGPoint(x: controller.window.frame.midX, y: controller.window.frame.midY)
            }
        }
        store.save()
    }

    func setLevel(_ level: NSWindow.Level) {
        windows.values.forEach { $0.window.level = level }
    }

    private func open(_ record: FloatingSheetRecord, level: NSWindow.Level) {
        let controller = FloatingSheetWindowController(record: record, model: model)
        controller.window.level = level
        controller.onMoved = { [weak self] center in
            guard let self, let i = store.state.floatingSheets.firstIndex(where: { $0.id == record.id }) else { return }
            store.state.floatingSheets[i].center = center
            store.save()
        }
        controller.onClick = { [weak self, weak controller] in
            controller?.crumpleUp { spin in
                guard let self, let current = self.store.state.floatingSheets.first(where: { $0.id == record.id }) else { return }
                var ball = current
                ball.rotation += spin
                self.onCrumpled(ball, spin)
                // Hand over on the next frame, once the ball window is showing.
                DispatchQueue.main.async { self.remove(record.id) }
            }
        }
        windows[record.id] = controller
        controller.window.orderFront(nil)
    }
}

/// One floating sheet: a borderless window just big enough for the rotated sheet and its shadow.
@MainActor
final class FloatingSheetWindowController {
    let window: NSWindow
    var onMoved: (CGPoint) -> Void = { _ in }
    var onClick: () -> Void = {}
    private let crumple = CrumpleState()
    private var crumpleTimer: Timer?
    private var crumpleDone: ((CGFloat) -> Void)?
    private var crumpleSpin: CGFloat = 0
    private var crumpleStart: TimeInterval = 0

    init(record: FloatingSheetRecord, model: PadModel) {
        let s = record.scale
        let w = PadView.sheetSize.width * s, h = PadView.sheetSize.height * s
        let margin = 30 * s
        let size = CGSize(width: abs(w * cos(record.rotation)) + abs(h * sin(record.rotation)) + margin * 2,
                          height: abs(w * sin(record.rotation)) + abs(h * cos(record.rotation)) + margin * 2)
        window = NSWindow(contentRect: CGRect(x: record.center.x - size.width / 2, y: record.center.y - size.height / 2,
                                              width: size.width, height: size.height),
                          styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let host = DraggableHostingView(rootView: FloatingSheetView(record: record, model: model, crumple: crumple))
        host.onDragEnded = { [weak self] _ in
            guard let self else { return }
            onMoved(CGPoint(x: window.frame.midX, y: window.frame.midY))
        }
        host.onClick = { [weak self] in self?.onClick() }
        window.contentView = host
    }

    func close() { window.orderOut(nil) }

    /// Scrunches the sheet into a ball in two squeezes, then calls `done` with the extra spin
    /// it picked up, so the ball window can carry on at the same angle.
    func crumpleUp(done: @escaping (CGFloat) -> Void) {
        guard crumpleTimer == nil else { return }
        SoundPlayer.shared.play("crumple")
        crumpleDone = done
        crumpleSpin = CGFloat.random(in: 0.4...0.9) * (Bool.random() ? 1 : -1)
        crumpleStart = ProcessInfo.processInfo.systemUptime
        crumpleTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.crumpleStep() }
        }
    }

    private func crumpleStep() {
        let x = min((ProcessInfo.processInfo.systemUptime - crumpleStart) / 0.7, 1)
        crumple.t = Self.squeezeCurve(x)
        crumple.spin = crumpleSpin * crumple.t
        if x >= 1 {
            crumpleTimer?.invalidate()
            crumpleTimer = nil
            crumpleDone?(crumpleSpin)
            crumpleDone = nil
        }
    }

    /// Two squeezes with a brief pause between, like scrunching paper in your hand.
    private static func squeezeCurve(_ x: Double) -> CGFloat {
        func easeOut(_ v: Double) -> Double { 1 - pow(1 - v, 3) }
        let y: Double
        switch x {
        case ..<0.38: y = 0.55 * easeOut(x / 0.38)
        case ..<0.5: y = 0.55 + 0.04 * (x - 0.38) / 0.12
        default: y = 0.59 + 0.41 * easeOut((x - 0.5) / 0.5)
        }
        return CGFloat(y)
    }
}

@MainActor
@Observable
final class CrumpleState {
    var t: CGFloat = 0
    var spin: CGFloat = 0
}

struct FloatingSheetView: View {
    let record: FloatingSheetRecord
    let model: PadModel
    let crumple: CrumpleState

    var body: some View {
        let theme = model.theme(scale: record.scale)
        let t = crumple.t
        Group {
            if t > 0 {
                CrumpledSheet(context: record.context, layout: model.layout, extras: record.extras,
                              tornFromLeft: record.tornFromLeft, t: t, wear: record.wear ?? 0)
            } else {
                SheetFace(context: record.context, layout: model.layout, extras: record.extras, torn: 1,
                          tornFromLeft: record.tornFromLeft, wear: record.wear ?? 0)
            }
        }
            .rotationEffect(.radians(record.rotation + crumple.spin))
            // A flat sheet casts a soft, wide shadow; a ball a tight one.
            .shadow(color: .black.opacity(0.3 + 0.1 * t), radius: theme.u(8 - 4 * t),
                    x: theme.u(1), y: theme.u(5 - 1 * t))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environment(\.cardTheme, theme)
    }
}
