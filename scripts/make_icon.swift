// Draws the app icon: a minimal tear-off sheet. Flat cream paper, a red binding band with
// a perforation row beneath, and த, the first letter of தமிழ் (Tamil).
// Usage: swift scripts/make_icon.swift RasiPalan/Assets.xcassets/AppIcon.appiconset

import AppKit

func drawIcon(in ctx: CGContext, size s: CGFloat) {
    let u = s / 1024
    // macOS icon tile.
    let tile = CGRect(x: 100 * u, y: 100 * u, width: 824 * u, height: 824 * u)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185 * u, cornerHeight: 185 * u, transform: nil)
    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()

    ctx.setFillColor(NSColor(red: 0.97, green: 0.95, blue: 0.90, alpha: 1).cgColor)
    ctx.fill(tile)

    // Binding band.
    let band = CGRect(x: tile.minX, y: tile.maxY - 220 * u, width: tile.width, height: 220 * u)
    ctx.setFillColor(NSColor(red: 0.82, green: 0.10, blue: 0.12, alpha: 1).cgColor)
    ctx.fill(band)

    // Perforation row (dropped at tiny sizes, where it would only be noise).
    if s >= 64 {
        ctx.setFillColor(NSColor(red: 0.82, green: 0.78, blue: 0.70, alpha: 1).cgColor)
        let n = 14
        for i in 0..<n {
            let x = tile.minX + tile.width * (CGFloat(i) + 0.5) / CGFloat(n)
            ctx.fillEllipse(in: CGRect(x: x - 9 * u, y: band.minY - 42 * u, width: 18 * u, height: 18 * u))
        }
    }

    // The letter, centred in the paper below the band.
    let font = NSFont(name: "TamilSangamMN-Bold", size: 470 * u) ?? .boldSystemFont(ofSize: 470 * u)
    let attr = NSAttributedString(string: "த", attributes: [
        .font: font, .foregroundColor: NSColor(red: 0.10, green: 0.09, blue: 0.08, alpha: 1)])
    let line = CTLineCreateWithAttributedString(attr)
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    let area = CGRect(x: tile.minX, y: tile.minY, width: tile.width, height: band.minY - 60 * u - tile.minY)
    ctx.textPosition = CGPoint(x: area.midX - bounds.midX, y: area.midY - bounds.midY)
    CTLineDraw(line, ctx)
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
