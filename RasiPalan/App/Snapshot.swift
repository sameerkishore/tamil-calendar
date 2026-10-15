#if DEBUG
import AppKit
import RasiCore
import SwiftUI

/// Debug helper: `RasiPalan -snapshot /path/out.png` renders the pad to a PNG and quits,
/// so the visuals can be checked without screen-recording access.
/// Optional: `-snapshotDay 2026-09-18`, `-snapshotStyle precise`.
@MainActor
enum Snapshot {
    static func renderPad(state: AppState, to url: URL) {
        let defaults = UserDefaults.standard
        var day = state.padDay
        if let s = defaults.string(forKey: "snapshotDay") {
            let p = s.split(separator: "-").compactMap { Int($0) }
            if p.count == 3 { day = CalendarDay(year: p[0], month: p[1], day: p[2]) }
        }
        let style = defaults.string(forKey: "snapshotStyle").flatMap(PanchangamStyle.init(rawValue:)) ?? state.style
        let context = DayContext(day: day, location: state.location ?? .fallback(for: .current), style: style)

        let renderer = ImageRenderer(content: PadView(model: PadModel(context: context), interactive: false)
            .background(Color(white: 0.85)))
        renderer.scale = 2
        guard let image = renderer.cgImage,
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else { return }
        try? data.write(to: url)
    }
}
#endif
