import AppKit
import Observation
import RasiCore
import SwiftUI

/// What the ball physics needs to know about the bin, in screen coordinates (AppKit, y up).
struct BinTarget {
    /// The bin's body, from its base to the rim.
    var body: CGRect
    /// Height of the rim line balls drop through.
    var rimY: CGFloat
    /// The opening at the rim, left to right.
    var mouth: ClosedRange<CGFloat>
    var isFull: Bool

    /// Half the body's width at height `y` (it tapers towards the base).
    func halfWidth(at y: CGFloat) -> CGFloat {
        let f = min(max((y - body.minY) / body.height, 0), 1)
        return body.width / 2 * (TrashBinView.baseRatio + (1 - TrashBinView.baseRatio) * f)
    }
}

/// The basket's plastic, chosen in Settings › Desktop.
enum BinColor: String, Codable, CaseIterable {
    case teal, red, blue, green, mustard, charcoal

    var title: String {
        switch self {
        case .teal: "Teal"
        case .red: "Red"
        case .blue: "Blue"
        case .green: "Green"
        case .mustard: "Mustard"
        case .charcoal: "Charcoal"
        }
    }

    /// Mid tone, shadowed side and highlight of the moulded plastic.
    var plastic: (base: Color, dark: Color, light: Color) {
        switch self {
        case .teal: (Color(red: 0.05, green: 0.42, blue: 0.43), Color(red: 0.02, green: 0.24, blue: 0.25), Color(red: 0.25, green: 0.62, blue: 0.62))
        case .red: (Color(red: 0.70, green: 0.16, blue: 0.13), Color(red: 0.42, green: 0.07, blue: 0.06), Color(red: 0.90, green: 0.38, blue: 0.32))
        case .blue: (Color(red: 0.12, green: 0.30, blue: 0.62), Color(red: 0.05, green: 0.15, blue: 0.36), Color(red: 0.36, green: 0.54, blue: 0.84))
        case .green: (Color(red: 0.22, green: 0.50, blue: 0.20), Color(red: 0.10, green: 0.28, blue: 0.10), Color(red: 0.46, green: 0.72, blue: 0.40))
        case .mustard: (Color(red: 0.84, green: 0.62, blue: 0.12), Color(red: 0.55, green: 0.38, blue: 0.04), Color(red: 0.97, green: 0.82, blue: 0.40))
        case .charcoal: (Color(red: 0.26, green: 0.27, blue: 0.29), Color(red: 0.12, green: 0.12, blue: 0.13), Color(red: 0.48, green: 0.49, blue: 0.52))
        }
    }
}

/// When the bin is on the desktop.
enum BinVisibility: String, Codable, CaseIterable {
    /// Always standing on the desktop, empty or not.
    case always
    /// Out while there are balls about or it has something in it.
    case whenNeeded
    /// Like `whenNeeded`, but it leaves a few seconds after the last ball is tossed, full or not.
    case autoHide
    /// Never shown.
    case hidden

    var title: String {
        switch self {
        case .always: "Always"
        case .whenNeeded: "Until emptied"
        case .autoHide: "Hide after tossing"
        case .hidden: "Never"
        }
    }
}

@MainActor
@Observable
final class BinModel {
    var count = 0
    var color: BinColor = .teal
    var isEmptying = false
    /// Bumps each time a ball lands in, to give the bin a little jolt.
    var landings = 0
    static let capacity = 10
    var isFull: Bool { count >= Self.capacity }
}

/// The waste-paper basket. Appears when there are paper balls about; click to empty it.
@MainActor
final class TrashBinController {
    let model = BinModel()
    private let store: StateStore
    private let window: NSWindow
    private var scale: CGFloat
    private var sprites: [Image] = []

    var isVisible: Bool { window.isVisible }

    init(store: StateStore, scale: CGFloat, sprites: [Image]) {
        self.store = store
        self.scale = scale
        self.sprites = sprites
        model.count = store.state.binCount
        model.color = store.state.binColor
        let size = Self.windowSize(scale: scale)
        window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
                          styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let host = DraggableHostingView(rootView: TrashBinView(model: model, scale: scale, sprites: sprites))
        self.host = host
        host.onDragEnded = { [weak self] _ in
            guard let self else { return }
            store.state.binCenter = CGPoint(x: window.frame.midX, y: window.frame.midY)
            store.save()
        }
        host.onClick = { [weak self] in self?.empty() }
        host.contextMenu = { [weak self] in
            let menu = NSMenu()
            let item = NSMenuItem(title: "Empty Bin", action: #selector(TrashBinMenuTarget.empty), keyEquivalent: "")
            item.target = self?.menuTarget
            item.isEnabled = (self?.model.count ?? 0) > 0
            menu.addItem(item)
            let clear = NSMenuItem(title: "Clear Desktop (sheets and balls)", action: #selector(TrashBinMenuTarget.clearDesktop), keyEquivalent: "")
            clear.target = self?.menuTarget
            menu.addItem(clear)
            return menu
        }
        window.contentView = host
        menuTarget.bin = self
    }

    private let menuTarget = TrashBinMenuTarget()
    private var host: DraggableHostingView<TrashBinView>?
    /// "Clear Desktop" from the bin's right-click menu.
    var onClearDesktop: () -> Void = {}

    /// Resizes the bin, keeping it standing where it is.
    func setScale(_ newScale: CGFloat) {
        guard abs(newScale - scale) > 0.001 else { return }
        scale = newScale
        let old = window.frame
        let size = Self.windowSize(scale: newScale)
        window.setFrame(CGRect(x: old.midX - size.width / 2, y: old.minY, width: size.width, height: size.height),
                        display: true)
        host?.rootView = TrashBinView(model: model, scale: newScale, sprites: sprites)
        store.state.binCenter = CGPoint(x: window.frame.midX, y: window.frame.midY)
    }

    static func windowSize(scale: CGFloat) -> CGSize {
        // Room around the bin for the heap above the rim, the tip-over and the shadow.
        CGSize(width: TrashBinView.size.width * 2 * scale, height: TrashBinView.size.height * 1.8 * scale)
    }

    func show(level: NSWindow.Level) {
        window.level = level
        guard !window.isVisible else { return }
        if let c = store.state.binCenter, NSScreen.screens.contains(where: { $0.frame.contains(c) }) {
            window.setFrameOrigin(CGPoint(x: c.x - window.frame.width / 2, y: c.y - window.frame.height / 2))
        } else {
            // Bottom right of the main screen, standing on the Dock line.
            let vf = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
            window.setFrameOrigin(CGPoint(x: vf.maxX - window.frame.width - 60 * scale, y: vf.minY))
        }
        window.alphaValue = 0
        window.orderFront(nil)
        NSAnimationContext.runAnimationGroup { $0.duration = 0.3; window.animator().alphaValue = 1 }
    }

    func hide() {
        guard window.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.3; window.animator().alphaValue = 0 },
                                             completionHandler: { [window] in MainActor.assumeIsolated { window.orderOut(nil) } })
    }

    func setLevel(_ level: NSWindow.Level) { window.level = level }

    func setColor(_ color: BinColor) {
        model.color = color
        store.state.binColor = color
        store.save()
    }

    func bringOnScreen() {
        if window.isVisible, ScreenFit.bringOnScreen(window) {
            store.state.binCenter = CGPoint(x: window.frame.midX, y: window.frame.midY)
            store.save()
        }
    }

    /// Where the bin is, for the ball physics. Nil while hidden.
    var target: BinTarget? {
        guard window.isVisible, window.alphaValue > 0.5 else { return nil }
        let f = window.frame
        let w = TrashBinView.size.width * scale, h = TrashBinView.size.height * scale
        let body = CGRect(x: f.midX - w / 2, y: f.minY + TrashBinView.groundGap * scale, width: w, height: h)
        let rimY = body.maxY - TrashBinView.rimHeight * scale / 2
        let inset = w * 0.05
        return BinTarget(body: body, rimY: rimY, mouth: (body.minX + inset)...(body.maxX - inset), isFull: model.isFull)
    }

    /// A ball dropped in.
    func accept() {
        model.count += 1
        model.landings += 1
        store.state.binCount = model.count
        store.save()
        SoundPlayer.shared.play("thunk", volume: model.count == 1 ? 0.9 : 0.7)
    }

    func empty() {
        guard model.count > 0, !model.isEmptying else { return }
        SoundPlayer.shared.play("bin-empty")
        withAnimation(.easeIn(duration: 0.35)) { model.isEmptying = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            guard let self else { return }
            model.count = 0
            store.state.binCount = 0
            store.save()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { model.isEmptying = false }
            onEmptied()
        }
    }

    var onEmptied: () -> Void = {}
}

/// NSMenuItem needs an Objective-C target.
@MainActor
final class TrashBinMenuTarget: NSObject {
    weak var bin: TrashBinController?
    @objc func empty() { bin?.empty() }
    @objc func clearDesktop() { bin?.onClearDesktop() }
}

/// A cheap plastic waste-paper basket: tapered, woven, teal like the calendar's band unless
/// recoloured in Settings, seen slightly from above so the heap inside shows as it fills.
struct TrashBinView: View {
    let model: BinModel
    let scale: CGFloat
    let sprites: [Image]

    /// At pad scale 1. The mouth is about twice a paper ball across.
    static let size = CGSize(width: 150, height: 158)
    static let rimHeight: CGFloat = 34
    nonisolated static let baseRatio: CGFloat = 0.74
    static let groundGap: CGFloat = 8

    /// Where each ball sits in the heap: x across the mouth (0…1), and how high it sits.
    private static let heap: [(x: CGFloat, lift: CGFloat)] = [
        (0.35, 0.00), (0.62, 0.02), (0.48, 0.10), (0.25, 0.18), (0.72, 0.20),
        (0.50, 0.30), (0.33, 0.40), (0.66, 0.42), (0.45, 0.55), (0.58, 0.66),
    ]

    var body: some View {
        let w = Self.size.width * scale, h = Self.size.height * scale
        let rim = Self.rimHeight * scale
        let ball = w * 0.4
        let (plastic, plasticDark, plasticLight) = model.color.plastic

        ZStack(alignment: .bottom) {
            // Shadow on the floor.
            Ellipse().fill(.black.opacity(0.28))
                .frame(width: w * 0.95, height: rim * 0.8)
                .blur(radius: 4 * scale)
                .offset(y: -Self.groundGap * scale + rim * 0.3)

            ZStack(alignment: .top) {
                // Inside of the basket, seen through the mouth.
                Ellipse().fill(plasticDark)
                    .frame(width: w, height: rim)

                // The heap: deeper balls are hidden behind the front wall; as it fills they rise
                // over the rim.
                ZStack(alignment: .topLeading) {
                    ForEach(0..<min(model.count, Self.heap.count), id: \.self) { i in
                        let spot = Self.heap[i]
                        sprites[i % max(sprites.count, 1)]
                            .resizable()
                            .frame(width: ball, height: ball)
                            .rotationEffect(.degrees(Double(i) * 47))
                            // The first balls just show inside the mouth; a full bin heaps over the rim.
                            .position(x: w * (0.12 + 0.76 * spot.x),
                                      y: rim * 0.95 + ball * 0.3 - spot.lift * ball * 1.35)
                    }
                }
                .frame(width: w, height: h)
                .offset(x: model.isEmptying ? w * 0.9 : 0, y: model.isEmptying ? -h * 0.5 : 0)
                .opacity(model.isEmptying ? 0 : 1)

                // Front wall, drawn over the hidden part of the heap.
                BinBody(baseRatio: Self.baseRatio, rim: rim)
                    .fill(LinearGradient(colors: [plasticDark, plastic, plasticLight, plastic, plasticDark],
                                         startPoint: .leading, endPoint: .trailing))
                    .overlay(
                        WovenPattern(scale: scale)
                            .stroke(plasticDark.opacity(0.75), lineWidth: 1.6 * scale)
                            .clipShape(BinBody(baseRatio: Self.baseRatio, rim: rim)))
                    .frame(width: w, height: h)

                // Rolled rim.
                Ellipse()
                    .stroke(LinearGradient(colors: [plasticLight, plastic], startPoint: .top, endPoint: .bottom),
                            lineWidth: 4 * scale)
                    .frame(width: w, height: rim)
            }
            .frame(width: w, height: h + rim / 2, alignment: .top)
            .padding(.bottom, Self.groundGap * scale)
            // Tipping over to empty, around the bottom-right corner.
            .rotationEffect(.degrees(model.isEmptying ? 32 : 0), anchor: .bottomTrailing)
            // Full: it can't take any more, and fidgets to say so. Only animates while full,
            // so an idle bin costs no CPU.
            .modifier(FullWobble(active: model.isFull && !model.isEmptying))
            // A little jolt when a ball lands.
            .keyframeAnimator(initialValue: 0.0, trigger: model.landings) { content, dy in
                content.offset(y: dy * scale)
            } keyframes: { _ in
                SpringKeyframe(3, duration: 0.06)
                SpringKeyframe(0, duration: 0.25, spring: .bouncy)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

private struct FullWobble: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content.phaseAnimator([-1.0, 1.0]) { view, phase in
                view.rotationEffect(.degrees(phase * 2.2), anchor: .bottom)
            } animation: { _ in .easeInOut(duration: 0.16) }
        } else {
            content
        }
    }
}

/// Tapered basket outline: wide at the rim, narrower at the base.
private struct BinBody: Shape {
    let baseRatio: CGFloat
    let rim: CGFloat

    func path(in rect: CGRect) -> Path {
        let inset = rect.width * (1 - baseRatio) / 2
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + rim / 2))
        // Front edge of the rim: the near half of the rim ellipse (a quad curve peaking at its bottom).
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + rim / 2),
                       control: CGPoint(x: rect.midX, y: rect.minY + rim * 1.5))
        p.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - rim * 0.25))
        p.addQuadCurve(to: CGPoint(x: rect.minX + inset, y: rect.maxY - rim * 0.25),
                       control: CGPoint(x: rect.midX, y: rect.maxY + rim * 0.25))
        p.closeSubpath()
        return p
    }
}

/// Diagonal lattice, like a woven plastic basket.
private struct WovenPattern: Shape {
    let scale: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let step = 9 * scale
        var x = rect.minX - rect.height
        while x < rect.maxX + rect.height {
            p.move(to: CGPoint(x: x, y: rect.minY))
            p.addLine(to: CGPoint(x: x + rect.height * 0.6, y: rect.maxY))
            p.move(to: CGPoint(x: x + rect.height * 0.6, y: rect.minY))
            p.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += step
        }
        // A plain band near the base, as moulded baskets have.
        p.addRect(CGRect(x: rect.minX, y: rect.maxY - 12 * scale, width: rect.width, height: 0.1))
        return p
    }
}

/// Small paper-ball pictures for the heap inside the bin, drawn once.
@MainActor
enum BallSprites {
    static func make(model: PadModel, count: Int = 4) -> [Image] {
        let theme = model.theme(scale: 1)
        let side = PadView.sheetSize.width * CrumpledSheet.ballSize * 1.3
        return (0..<count).compactMap { i in
            let day = model.context.day.adding(days: -(i + 1) * 3)
            let context = DayContext(day: day, location: model.context.location, style: model.context.style)
            let renderer = ImageRenderer(content:
                CrumpledSheet(context: context, layout: model.layout, t: 1)
                    .frame(width: side, height: side)
                    .clipped()
                    .environment(\.cardTheme, theme))
            renderer.scale = 2
            return renderer.cgImage.map { Image(decorative: $0, scale: 2) }
        }
    }
}
