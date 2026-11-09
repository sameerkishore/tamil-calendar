import AppKit
import SwiftUI

/// A paper ball in the air, in screen coordinates (AppKit, y up), scaled with the ball. A value
/// stepped at a fixed rate, so the aiming line can fly a copy and draw exactly what the ball will do.
struct BallFlight {
    static let stepTime: TimeInterval = 1.0 / 120
    /// Silly speeds from a jerk of the mouse are capped here, in points per second at scale 1.
    private static let topSpeed: CGFloat = 1_900

    enum Contact {
        case none
        /// Went in; `clippedRim` if it caught the edge on the way.
        case binned(BinTarget, clippedRim: Bool)
        /// Bounced off the rim, or off the heap of a full bin.
        case rim(full: Bool)
        case floor(speed: CGFloat)
        /// Stopped rolling.
        case settled
    }

    let scale: CGFloat
    /// The usable part of the display it's flying on.
    let screen: CGRect
    private(set) var position: CGPoint
    private(set) var velocity: CGVector

    var radius: CGFloat { 30 * scale }
    private var gravity: CGFloat { 2_200 * scale }
    /// How hard it's going, 0…1 of the fastest throw.
    var power: CGFloat { min(hypot(velocity.dx, velocity.dy) / (Self.topSpeed * scale), 1) }

    init(from start: CGPoint, velocity v: CGVector, scale: CGFloat, screen: CGRect) {
        self.scale = scale
        self.screen = screen
        position = start
        let speed = hypot(v.dx, v.dy), cap = Self.topSpeed * scale
        velocity = speed > cap ? CGVector(dx: v.dx / speed * cap, dy: v.dy / speed * cap) : v
    }

    /// The launch a full pull gives; shorter pulls get their share of it.
    static func launch(for pull: BallPull, scale: CGFloat) -> CGVector {
        let perPoint = topSpeed * scale / BallPull.maxLength
        return CGVector(dx: pull.vector.dx * perPoint, dy: pull.vector.dy * perPoint)
    }

    mutating func step(bin: BinTarget?) -> Contact {
        let dt = CGFloat(Self.stepTime)
        let r = radius
        let previous = position
        var contact = Contact.none

        velocity.dy -= gravity * dt
        velocity.dx *= 1 - 0.6 * dt    // paper balls are light: noticeable air drag
        position.x += velocity.dx * dt
        position.y += velocity.dy * dt

        if let bin {
            let result = collide(with: bin, previous: previous)
            if case .binned = result { return result }
            contact = result
        }

        // Screen edges and the floor (the top of the Dock).
        var onFloor = false
        if position.x < screen.minX + r { position.x = screen.minX + r; velocity.dx = abs(velocity.dx) * 0.5 }
        if position.x > screen.maxX - r { position.x = screen.maxX - r; velocity.dx = -abs(velocity.dx) * 0.5 }
        if position.y > screen.maxY - r { position.y = screen.maxY - r; velocity.dy = -abs(velocity.dy) * 0.3 }
        if position.y < screen.minY + r {
            position.y = screen.minY + r
            if velocity.dy < -160 * scale {
                contact = .floor(speed: -velocity.dy)
                velocity.dy = -velocity.dy * 0.35
            } else {
                velocity.dy = 0
                onFloor = true
            }
            velocity.dx *= 0.82   // paper doesn't roll far
        }
        return onFloor && abs(velocity.dx) < 12 * scale ? .settled : contact
    }

    /// Rim, sides and mouth.
    private mutating func collide(with bin: BinTarget, previous: CGPoint) -> Contact {
        let r = radius
        var contact = Contact.none
        // Crossing the rim line on the way down.
        if previous.y >= bin.rimY && position.y < bin.rimY && velocity.dy < 0 {
            if bin.mouth.contains(position.x) && !bin.isFull {
                return .binned(bin, clippedRim: false)
            }
            // Just inside the rim: catch the edge and tip in, rather than bouncing out.
            if position.x > bin.body.minX && position.x < bin.body.maxX && !bin.isFull {
                return .binned(bin, clippedRim: true)
            }
            if position.x > bin.body.minX - r * 0.7 && position.x < bin.body.maxX + r * 0.7 {
                // Clipped the rim (or landed on a full heap): bounce up and away from the middle.
                contact = .rim(full: bin.isFull)
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
        return contact
    }

    /// The first stretch of the flight: enough to show the direction, and deliberately not where
    /// it ends up, so getting it in the bin is still a shot. Knows nothing about the bin.
    func opening(length: CGFloat) -> [CGPoint] {
        var ball = self
        var path = [position]
        var travelled: CGFloat = 0
        for _ in 1...(2 * 120) where travelled < length {
            let last = ball.position
            switch ball.step(bin: nil) {
            case .floor, .settled: return path
            default: break
            }
            travelled += hypot(ball.position.x - last.x, ball.position.y - last.y)
            path.append(ball.position)
        }
        return path
    }
}

/// How far back the ball is being pulled, and so which way and how hard it will go.
struct BallPull {
    /// Dragging further than this, in points, adds nothing.
    static let maxLength: CGFloat = 300
    /// A shorter pull lets the ball go without launching it.
    private static let minLength: CGFloat = 28

    /// Points the way the ball will fly (opposite the hand), at most `maxLength` long.
    let vector: CGVector
    /// The tab's offset from the ball's centre, capped like the pull, for drawing the ribbon.
    let reach: CGVector

    var power: CGFloat { hypot(vector.dx, vector.dy) / Self.maxLength }
    var launches: Bool { hypot(vector.dx, vector.dy) >= Self.minLength }

    /// Measured from the ball's centre, so it flies directly away from the hand. `slack` is how far
    /// from the centre the tab sits at rest: pulling only counts beyond that.
    ///
    /// A ball on the floor or against a wall has no room behind it for the hand to pull into, so
    /// travel towards a near screen edge counts for more: reaching the edge is always a full pull.
    init(ball: CGPoint, hand: CGPoint, slack: CGFloat, display: CGRect) {
        let longest = Self.maxLength + slack
        func stretched(_ travel: CGFloat, roomBefore: CGFloat, roomAfter: CGFloat) -> CGFloat {
            let room = min(max(travel < 0 ? roomBefore : roomAfter, 40), longest)
            return travel * longest / room
        }
        let offset = CGVector(dx: hand.x - ball.x, dy: hand.y - ball.y)
        let dx = stretched(offset.dx, roomBefore: ball.x - display.minX, roomAfter: display.maxX - ball.x)
        let dy = stretched(offset.dy, roomBefore: ball.y - display.minY, roomAfter: display.maxY - ball.y)
        let length = hypot(dx, dy)
        let strength = min(max(length - slack, 0), Self.maxLength)
        vector = length > 0 ? CGVector(dx: -dx / length * strength, dy: -dy / length * strength) : .zero
        let handLength = hypot(offset.dx, offset.dy)
        let shrink = handLength > longest ? longest / handLength : 1
        reach = CGVector(dx: offset.dx * shrink, dy: offset.dy * shrink)
    }
}

/// The stub you pull a ball back by: a torn-off corner of the sheet, tucked in behind the ball.
struct BallPullTab: View {
    /// இழு, "pull", until it's being pulled; then the strength in Tamil numerals.
    var label = "இழு"
    let scale: CGFloat

    static let size = CGSize(width: 44, height: 32)
    /// Stays big enough to grab on a small pad, and doesn't turn into a flag on a huge one.
    static func scale(forBall ballScale: CGFloat) -> CGFloat { min(max(ballScale, 0.85), 1.3) }
    /// From the ball's centre to the tab's, y up.
    static func offset(forBall ballScale: CGFloat) -> CGVector {
        CGVector(dx: 5 * ballScale, dy: 39 * ballScale + (size.height / 2 - 8) * scale(forBall: ballScale))
    }

    var body: some View {
        let w = Self.size.width * scale, h = Self.size.height * scale
        ZStack {
            TabStub().fill(Ink.paper)
            // Printed rule, the red plate a hair out of register with the black.
            Rectangle().stroke(Ink.red, lineWidth: 1.2 * scale)
                .frame(width: w - 8 * scale, height: h - 13 * scale)
                .offset(x: 0.7 * scale, y: -2.3 * scale)
            Rectangle().stroke(Ink.black, lineWidth: 0.7 * scale)
                .frame(width: w - 8 * scale, height: h - 13 * scale)
                .offset(y: -3 * scale)
            Text(label)
                .font(.custom("TamilSangamMN-Bold", size: 13 * scale))
                .foregroundStyle(Ink.red)
                .offset(y: -3 * scale)
        }
        .frame(width: w, height: h)
        .shadow(color: .black.opacity(0.35), radius: 2 * scale, x: 0.5 * scale, y: 1.5 * scale)
    }
}

/// A slip of paper with a scalloped lower edge, where it came away along the perforation.
private struct TabStub: Shape {
    func path(in rect: CGRect) -> Path {
        let scallops = 5
        let step = rect.width / CGFloat(scallops)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        for i in stride(from: scallops, to: 0, by: -1) {
            let right = rect.minX + CGFloat(i) * step
            p.addQuadCurve(to: CGPoint(x: right - step, y: rect.maxY),
                           control: CGPoint(x: right - step / 2, y: rect.maxY - step * 0.75))
        }
        p.closeSubpath()
        return p
    }
}

/// What the aiming overlay draws, in the overlay's own coordinates (y down).
struct BallAimPicture {
    var ball: CGPoint = .zero
    var hand: CGPoint = .zero
    /// The opening of the flight; empty until the pull is enough to launch.
    var path: [CGPoint] = []
    var power: CGFloat = 0
    var ballRadius: CGFloat = 30
    var tabScale: CGFloat = 1
}

/// A transparent, click-through sheet over the whole display, just under the ball, that exists only
/// while aiming.
@MainActor
final class BallAimOverlay {
    private final class Box { var picture = BallAimPicture() }

    private let window: NSWindow
    private let box = Box()
    private let frame: CGRect

    init(display: CGRect, under ball: NSWindow) {
        frame = display
        window = NSWindow(contentRect: display, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.level = ball.level
        window.contentView = NSHostingView(rootView: Self.view(box))
        window.order(.below, relativeTo: ball.windowNumber)
    }

    /// Redrawn every frame anyway to march the dots, so the picture needs no observing.
    private static func view(_ box: Box) -> some View {
        TimelineView(.animation) { timeline in
            BallAimDrawing(picture: box.picture, time: timeline.date.timeIntervalSinceReferenceDate)
        }
    }

    func show(ball: CGPoint, hand: CGPoint, path: [CGPoint], power: CGFloat,
              ballRadius: CGFloat, tabScale: CGFloat) {
        box.picture = BallAimPicture(ball: local(ball), hand: local(hand), path: path.map(local),
                                     power: power, ballRadius: ballRadius, tabScale: tabScale)
    }

    func close() {
        window.orderOut(nil)
    }

    private func local(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x - frame.minX, y: frame.maxY - p.y) }
}

/// The pull, printed the way the sheets are: a newsprint ribbon drawn out of the ball, a row of red
/// dots marching down it, the tab at the hand counting the strength in Tamil numerals, and a few
/// printer's marks fading out along the way the ball will go.
struct BallAimDrawing: View {
    let picture: BallAimPicture
    let time: TimeInterval

    private static let numerals = ["௧", "௨", "௩", "௪", "௫", "௬", "௭", "௮", "௯", "௰"]
    /// How far past the ball the direction marks reach.
    static let hintLength: CGFloat = 150

    var body: some View {
        ZStack {
            Canvas { context, _ in
                drawRibbon(in: context)
                drawHint(in: context)
            }
            let slant = max(min((picture.hand.x - picture.ball.x) / 300, 1), -1) * 12
            BallPullTab(label: picture.path.isEmpty ? "இழு" : Self.numerals[min(Int(picture.power * 10), 9)],
                        scale: picture.tabScale)
                .rotationEffect(.degrees(slant))
                .position(picture.hand)
        }
    }

    private func drawRibbon(in context: GraphicsContext) {
        let root = picture.ball
        let dx = picture.hand.x - root.x, dy = picture.hand.y - root.y
        let length = hypot(dx, dy)
        guard length > 1 else { return }
        let half = 7 * picture.tabScale
        let normal = CGVector(dx: -dy / length * half, dy: dx / length * half)

        var ribbon = Path()
        ribbon.move(to: root)
        ribbon.addLine(to: picture.hand)
        context.stroke(ribbon, with: .color(.black.opacity(0.3)), style: StrokeStyle(lineWidth: half * 2 + 2.5))
        context.stroke(ribbon, with: .color(Ink.paper), style: StrokeStyle(lineWidth: half * 2))

        // The rows of holes down each edge, like the top of a sheet.
        for side: CGFloat in [-0.68, 0.68] {
            var edge = Path()
            edge.move(to: CGPoint(x: root.x + normal.dx * side, y: root.y + normal.dy * side))
            edge.addLine(to: CGPoint(x: picture.hand.x + normal.dx * side, y: picture.hand.y + normal.dy * side))
            context.stroke(edge, with: .color(Ink.faded),
                           style: StrokeStyle(lineWidth: 1.4 * picture.tabScale, lineCap: .round, dash: [0.01, 4.5 * picture.tabScale]))
        }

        // Rising phase runs the dots towards the start of the path: in, to the ball.
        let size = (2.8 + 1.8 * picture.power) * picture.tabScale
        let style = StrokeStyle(lineWidth: size, lineCap: .round, dash: [0.01, 11 * picture.tabScale],
                                dashPhase: CGFloat(time * 40))
        var offRegister = context
        offRegister.translateBy(x: 0.7, y: 0.7)
        offRegister.stroke(ribbon, with: .color(Ink.black.opacity(0.75)), style: style)
        context.stroke(ribbon, with: .color(Ink.red), style: style)
    }

    /// Marks stamped along the opening of the flight, coming out from behind the ball and gone
    /// well before it lands.
    private func drawHint(in context: GraphicsContext) {
        guard picture.path.count > 1 else { return }
        let start = picture.ballRadius * 1.5, end = start + Self.hintLength
        let spacing: CGFloat = 25
        let drift = CGFloat((time * 45).truncatingRemainder(dividingBy: Double(spacing * 2)))
        var i = 0
        var distance = start + drift - spacing * 2
        while distance < end {
            defer { distance += spacing; i += 1 }
            guard distance >= start, let point = Self.point(along: picture.path, at: distance) else { continue }
            let fromStart = (distance - start) / Self.hintLength
            let fade = min(fromStart * 6, 1) * (1 - fromStart)
            var mark = context
            mark.opacity = fade
            Self.stamp(in: mark, at: point, diamond: i.isMultiple(of: 2), size: 5.5 * picture.tabScale * (1 - fromStart * 0.35))
        }
    }

    /// A little paper token, its red centre printed slightly off the black outline.
    private static func stamp(in context: GraphicsContext, at p: CGPoint, diamond: Bool, size: CGFloat) {
        func outline(_ r: CGFloat, dx: CGFloat = 0, dy: CGFloat = 0) -> Path {
            let c = CGPoint(x: p.x + dx, y: p.y + dy)
            if !diamond { return Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)) }
            var d = Path()
            d.move(to: CGPoint(x: c.x, y: c.y - r * 1.25))
            d.addLine(to: CGPoint(x: c.x + r * 1.25, y: c.y))
            d.addLine(to: CGPoint(x: c.x, y: c.y + r * 1.25))
            d.addLine(to: CGPoint(x: c.x - r * 1.25, y: c.y))
            d.closeSubpath()
            return d
        }
        context.fill(outline(size + 1.6), with: .color(.black.opacity(0.3)))
        context.fill(outline(size), with: .color(Ink.paper))
        context.stroke(outline(size * 0.98), with: .color(Ink.black), lineWidth: 0.8)
        context.fill(outline(size * 0.5, dx: 0.8, dy: 0.7), with: .color(Ink.red))
    }

    private static func point(along path: [CGPoint], at distance: CGFloat) -> CGPoint? {
        var left = distance
        for (a, b) in zip(path, path.dropFirst()) {
            let step = hypot(b.x - a.x, b.y - a.y)
            if left <= step, step > 0 {
                return CGPoint(x: a.x + (b.x - a.x) * left / step, y: a.y + (b.y - a.y) * left / step)
            }
            left -= step
        }
        return nil
    }
}
