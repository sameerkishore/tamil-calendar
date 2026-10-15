import AppKit
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

    var context: DayContext { DayContext(day: day, location: location, style: style) }
}

/// Owns every floating sheet window.
@MainActor
final class FloatingSheetsController {
    private let store: StateStore
    private let model: PadModel
    private var windows: [UUID: FloatingSheetWindowController] = [:]
    /// Clicked (not dragged): milestone 5 crumples it.
    var onClick: (UUID) -> Void = { _ in }

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
                                         tornFromLeft: sheet.tornFromLeft)
        store.state.floatingSheets.append(record)
        store.save()
        open(record, level: level)
    }

    func remove(_ id: UUID) {
        windows.removeValue(forKey: id)?.close()
        store.state.floatingSheets.removeAll { $0.id == id }
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
        controller.onClick = { [weak self] in self?.onClick(record.id) }
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

        let host = FloatingSheetHostingView(rootView: FloatingSheetView(record: record, model: model))
        host.onDragEnded = { [weak self] in
            guard let self else { return }
            onMoved(CGPoint(x: window.frame.midX, y: window.frame.midY))
        }
        host.onClick = { [weak self] in self?.onClick() }
        window.contentView = host
    }

    func close() { window.orderOut(nil) }
}

/// Drag anywhere to move the sheet; a click without movement is reported separately.
final class FloatingSheetHostingView: NSHostingView<FloatingSheetView> {
    var onDragEnded: () -> Void = {}
    var onClick: () -> Void = {}
    private var start: CGPoint = .zero
    private var startOrigin: CGPoint = .zero
    private var dragged = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        start = NSEvent.mouseLocation
        startOrigin = window?.frame.origin ?? .zero
        dragged = false
    }

    override func mouseDragged(with event: NSEvent) {
        let p = NSEvent.mouseLocation
        if !dragged && hypot(p.x - start.x, p.y - start.y) < 3 { return }
        if !dragged { NSCursor.closedHand.push() }
        dragged = true
        window?.setFrameOrigin(CGPoint(x: startOrigin.x + p.x - start.x, y: startOrigin.y + p.y - start.y))
    }

    override func mouseUp(with event: NSEvent) {
        if dragged {
            NSCursor.pop()
            onDragEnded()
        } else {
            onClick()
        }
    }
}

struct FloatingSheetView: View {
    let record: FloatingSheetRecord
    let model: PadModel

    var body: some View {
        let theme = CardTheme(scale: record.scale, language: model.language)
        SheetFace(context: record.context, layout: model.layout, torn: 1, tornFromLeft: record.tornFromLeft)
            .rotationEffect(.radians(record.rotation))
            .shadow(color: .black.opacity(0.3), radius: theme.u(8), x: theme.u(1), y: theme.u(5))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environment(\.cardTheme, theme)
    }
}
