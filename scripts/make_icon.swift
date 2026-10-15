// Draws the app icon: a tear-off calendar sheet on a maroon tile, its corner folding over.
// Usage: swift scripts/make_icon.swift RasiPalan/Assets.xcassets/AppIcon.appiconset

import AppKit

func drawIcon(in ctx: CGContext, size s: CGFloat) {
    let u = s / 1024
    ctx.saveGState()
    defer { ctx.restoreGState() }

    // macOS icon tile: rounded square inset from the canvas, with a soft drop shadow.
    let tile = CGRect(x: 100 * u, y: 100 * u, width: 824 * u, height: 824 * u)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185 * u, cornerHeight: 185 * u, transform: nil)
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * u), blur: 24 * u, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    ctx.addPath(tilePath)
    ctx.setFillColor(NSColor(red: 0.55, green: 0.10, blue: 0.16, alpha: 1).cgColor)
    ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0)

    // Maroon board with a warm glow from the top.
    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let glow = CGGradient(colorsSpace: nil, colors: [
        NSColor(red: 0.85, green: 0.30, blue: 0.25, alpha: 1).cgColor,
        NSColor(red: 0.50, green: 0.08, blue: 0.14, alpha: 1).cgColor,
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(glow, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])
    // Teal band across, like the calendar board.
    ctx.setFillColor(NSColor(red: 0.05, green: 0.42, blue: 0.43, alpha: 1).cgColor)
    ctx.fill(CGRect(x: tile.minX, y: 250 * u, width: tile.width, height: 170 * u))
    ctx.restoreGState()

    // The sheet, slightly tilted.
    ctx.saveGState()
    ctx.translateBy(x: 512 * u, y: 500 * u)
    ctx.rotate(by: -0.06)
    let w = 470 * u, h = 560 * u
    let sheet = CGRect(x: -w / 2, y: -h / 2 - 20 * u, width: w, height: h)
    let fold = 120 * u
    // Paper outline with the bottom-right corner folded away.
    let paper = CGMutablePath()
    paper.move(to: CGPoint(x: sheet.minX, y: sheet.maxY))
    paper.addLine(to: CGPoint(x: sheet.maxX, y: sheet.maxY))
    paper.addLine(to: CGPoint(x: sheet.maxX, y: sheet.minY + fold))
    paper.addLine(to: CGPoint(x: sheet.maxX - fold, y: sheet.minY))
    paper.addLine(to: CGPoint(x: sheet.minX, y: sheet.minY))
    paper.closeSubpath()
    ctx.setShadow(offset: CGSize(width: 0, height: -8 * u), blur: 18 * u, color: NSColor.black.withAlphaComponent(0.4).cgColor)
    ctx.addPath(paper)
    ctx.setFillColor(NSColor(red: 0.97, green: 0.95, blue: 0.90, alpha: 1).cgColor)
    ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0)

    // Red binding strip with staples.
    let strip = CGRect(x: sheet.minX - 6 * u, y: sheet.maxY - 6 * u, width: w + 12 * u, height: 70 * u)
    ctx.setFillColor(NSColor(red: 0.82, green: 0.10, blue: 0.12, alpha: 1).cgColor)
    ctx.fill(strip)
    ctx.setFillColor(NSColor(white: 0.92, alpha: 1).cgColor)
    for x in [sheet.minX + 90 * u, sheet.maxX - 150 * u] {
        ctx.fill(CGRect(x: x, y: strip.midY - 6 * u, width: 60 * u, height: 12 * u))
    }

    // Big date and weekday, letterpress style.
    func draw(_ text: String, font: NSFont, color: NSColor, centerX: CGFloat, baseline: CGFloat, condense: CGFloat = 1) {
        let attr = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
        let line = CTLineCreateWithAttributedString(attr)
        let width = CTLineGetTypographicBounds(line, nil, nil, nil)
        ctx.saveGState()
        ctx.translateBy(x: centerX, y: baseline)
        ctx.scaleBy(x: condense, y: 1)
        ctx.textPosition = CGPoint(x: -width / 2, y: 0)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }
    let numeral = NSFont(name: "Superclarendon-Black", size: 300 * u) ?? .boldSystemFont(ofSize: 300 * u)
    draw("15", font: numeral, color: NSColor(red: 0.10, green: 0.09, blue: 0.08, alpha: 1),
         centerX: sheet.midX - 10 * u, baseline: sheet.minY + 210 * u, condense: 0.82)
    let tamil = NSFont(name: "TamilSangamMN-Bold", size: 76 * u) ?? .boldSystemFont(ofSize: 76 * u)
    draw("வியாழன்", font: tamil, color: NSColor(red: 0.82, green: 0.10, blue: 0.12, alpha: 1),
         centerX: sheet.midX - 30 * u, baseline: sheet.minY + 80 * u)

    // The folded-over corner, showing the paper's back.
    let flap = CGMutablePath()
    flap.move(to: CGPoint(x: sheet.maxX, y: sheet.minY + fold))
    flap.addLine(to: CGPoint(x: sheet.maxX - fold, y: sheet.minY))
    flap.addLine(to: CGPoint(x: sheet.maxX - fold, y: sheet.minY + fold))
    flap.closeSubpath()
    ctx.setShadow(offset: CGSize(width: -6 * u, height: 6 * u), blur: 12 * u, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    ctx.addPath(flap)
    ctx.setFillColor(NSColor(red: 0.88, green: 0.85, blue: 0.78, alpha: 1).cgColor)
    ctx.fillPath()
    ctx.restoreGState()
}

let dir = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "RasiPalan/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let px = points * factor
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        drawIcon(in: NSGraphicsContext.current!.cgContext, size: CGFloat(px))
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(points)x\(points)\(factor == 2 ? "@2x" : "").png"
        try rep.representation(using: .png, properties: [:])!.write(to: dir.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(factor)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["version": 1, "author": "xcode"]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: dir.appendingPathComponent("Contents.json"))
let catalog = dir.deletingLastPathComponent().appendingPathComponent("Contents.json")
try #"{ "info" : { "author" : "xcode", "version" : 1 } }"#.write(to: catalog, atomically: true, encoding: .utf8)
print("Wrote \(images.count) icon sizes to \(dir.path)")
