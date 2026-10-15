import AppKit
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

/// Owns every paper ball window.
@MainActor
final class PaperBallsController {
    private let store: StateStore
    private let model: PadModel
    private var windows: [UUID: PaperBallWindowController] = [:]

    init(store: StateStore, model: PadModel) {
        self.store = store
        self.model = model
    }

    func restore(level: NSWindow.Level) {
        for record in store.state.paperBalls {
            open(record, level: level)
        }
    }

    func add(_ record: PaperBallRecord, level: NSWindow.Level) {
        store.state.paperBalls.append(record)
        store.save()
        open(record, level: level)
    }

    func remove(_ id: UUID) {
        windows.removeValue(forKey: id)?.close()
        store.state.paperBalls.removeAll { $0.id == id }
        store.save()
    }

    func setLevel(_ level: NSWindow.Level) {
        windows.values.forEach { $0.window.level = level }
    }

    private func open(_ record: PaperBallRecord, level: NSWindow.Level) {
        let controller = PaperBallWindowController(record: record, model: model)
        controller.window.level = level
        controller.onMoved = { [weak self] center in
            guard let self, let i = store.state.paperBalls.firstIndex(where: { $0.id == record.id }) else { return }
            store.state.paperBalls[i].center = center
            store.save()
        }
        controller.onClick = { SoundPlayer.shared.play("rustle", volume: 0.5) } // throwing arrives in milestone 6
        windows[record.id] = controller
        controller.window.orderFront(nil)
    }
}

/// One paper ball: a small borderless window around the ball and its shadow.
@MainActor
final class PaperBallWindowController {
    let window: NSWindow
    var onMoved: (CGPoint) -> Void = { _ in }
    var onClick: () -> Void = {}

    /// Window side, in points: ball plus room for lumps and shadow.
    static func side(scale: CGFloat) -> CGFloat {
        PadView.sheetSize.width * CrumpledSheet.ballSize * 1.3 * scale + 24 * scale
    }

    init(record: PaperBallRecord, model: PadModel) {
        let side = Self.side(scale: record.scale)
        window = NSWindow(contentRect: CGRect(x: record.center.x - side / 2, y: record.center.y - side / 2,
                                              width: side, height: side),
                          styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let host = DraggableHostingView(rootView: PaperBallView(record: record, model: model, side: side))
        host.onDragEnded = { [weak self] in
            guard let self else { return }
            onMoved(CGPoint(x: window.frame.midX, y: window.frame.midY))
        }
        host.onClick = { [weak self] in self?.onClick() }
        window.contentView = host
    }

    func close() { window.orderOut(nil) }
}

struct PaperBallView: View {
    let record: PaperBallRecord
    let model: PadModel
    let side: CGFloat

    var body: some View {
        let theme = model.theme(scale: record.scale)
        // Same drawing as the end of the crumple animation, so the hand-over is seamless.
        CrumpledSheet(context: record.context, layout: model.layout, tornFromLeft: record.tornFromLeft, t: 1)
            .rotationEffect(.radians(record.rotation))
            .shadow(color: .black.opacity(0.4), radius: theme.u(4), x: theme.u(1), y: theme.u(4))
            .frame(width: side, height: side)
            .environment(\.cardTheme, theme)
    }
}
