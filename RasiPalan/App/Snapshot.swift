#if DEBUG
import AppKit
import SwiftUI

/// Debug helper: `RasiPalan -snapshot /path/out.png` renders the pad to a PNG and quits,
/// so the visuals can be checked without screen-recording access.
@MainActor
enum Snapshot {
    static func renderPad(day: CalendarDay, to url: URL) {
        let renderer = ImageRenderer(content: PadView(day: day, interactive: false).background(Color(white: 0.85)))
        renderer.scale = 2
        guard let image = renderer.cgImage,
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else { return }
        try? data.write(to: url)
    }
}
#endif
