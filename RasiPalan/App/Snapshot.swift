#if DEBUG
import AppKit
import RasiCore
import SwiftUI

/// Debug helper: `RasiPalan -snapshot /path/out.png` renders the pad to a PNG and quits,
/// so the visuals can be checked without screen-recording access.
/// Optional: `-snapshotDay 2026-09-18`, `-snapshotStyle precise`, `-snapshotLanguage english`, `-snapshotScale 2`.
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
        let language = defaults.string(forKey: "snapshotLanguage").flatMap(CardLanguage.init(rawValue:)) ?? state.language
        let scale = CGFloat(defaults.double(forKey: "snapshotScale").nonZero ?? 1)

        let model = PadModel(context: context, language: language, scale: scale)
        model.perforations = state.physics.holes
        let theme = model.theme()
        var content = AnyView(PadView(model: model, interactive: false))

        // -snapshotTear 0.6: the top sheet mid-tear, swung and bent, over the pad.
        let tear = defaults.double(forKey: "snapshotTear")
        if tear > 0 {
            model.isTearing = true
            let size = CGSize(width: theme.u(PadView.sheetSize.width), height: theme.u(PadView.sheetSize.height))
            let origin = CGPoint(x: theme.u(PadView.margin) + 60, y: theme.u(PadView.margin + PadView.gripHeight) + 40)
            let state = TearState(context: context, layout: model.layout, theme: theme, origin: origin, size: size)
            state.progress = tear
            state.fromRight = defaults.bool(forKey: "snapshotFromRight")
            state.fold = CGSize(width: size.width * 0.8 * tear * (state.fromRight ? -1 : 1), height: -size.height * 0.35 * tear)
            content = AnyView(ZStack(alignment: .topLeading) {
                PadView(model: model, interactive: false).padding(.leading, 60).padding(.top, 40)
                TearOverlayView(state: state).environment(\.cardTheme, theme)
            }.frame(width: 700, height: 700, alignment: .topLeading))
        }

        // -snapshotCrumple 1: crumple stages side by side.
        if defaults.double(forKey: "snapshotCrumple") > 0 {
            content = AnyView(HStack(spacing: 0) {
                ForEach([0.0, 0.3, 0.55, 0.8, 1.0], id: \.self) { t in
                    CrumpledSheet(context: context, layout: model.layout, t: t)
                        .shadow(color: .black.opacity(0.3), radius: 6, y: 4)
                        .padding(10)
                }
            }.environment(\.cardTheme, theme))
        }

        // -snapshotBin 1: the bin empty, part full and full.
        if defaults.double(forKey: "snapshotBin") > 0 {
            let sprites = BallSprites.make(model: model)
            let binSize = TrashBinController.windowSize(scale: 1.5)
            content = AnyView(HStack(spacing: 0) {
                ForEach([0, 4, 7, 10], id: \.self) { n in
                    let bin = BinModel()
                    let _ = bin.count = n
                    TrashBinView(model: bin, scale: 1.5, sprites: sprites)
                        .frame(width: binSize.width, height: binSize.height)
                }
            })
        }

        // -snapshotTemplates 1: today's sheet in every template.
        if defaults.double(forKey: "snapshotTemplates") > 0 {
            content = AnyView(HStack(spacing: 20) {
                ForEach(CardLayout.all) { layout in
                    SheetFace(context: context, layout: layout)
                        .environment(\.cardTheme, CardTheme(scale: 1, language: language, paper: layout.paper))
                }
            }.padding(20))
        }

        // -snapshotBoard temple: the pad on a board.
        if let board = defaults.string(forKey: "snapshotBoard").flatMap(BoardStyle.init(rawValue:)) {
            model.board = board
            if let path = defaults.string(forKey: "snapshotImage") { model.boardImage = NSImage(contentsOfFile: path) }
            content = AnyView(PadView(model: model, interactive: false))
        }

        // -snapshotPersonal 1: a custom layout with the personal blocks, filled with sample data.
        if defaults.double(forKey: "snapshotPersonal") > 0 {
            let draft = LayoutDraft(from: .classic)
            draft.items = [
                .init(type: PanchangamBlock.type), .init(type: TimingsBlock.type),
                .init(type: WeatherBlock.type), .init(type: HoroscopeBlock.type),
                .init(type: EventsBlock.type, params: ["max": "3"]), .init(type: RemindersBlock.type, params: ["max": "3"]),
            ]
            draft.footer = true
            let sample = DayExtras(
                reminders: ["Pay electricity bill", "அம்மாவுக்கு போன் பண்ணு", "Buy flowers", "Return library book"],
                events: [PrintedEvent(time: nil, title: "Navaratri holiday"), PrintedEvent(time: "9.30", title: "Team standup"),
                         PrintedEvent(time: "6", title: "Temple with family")],
                weather: PrintedWeather(code: 95, high: 31.4, low: 24.6, rain: 70))
            var t = theme
            t.myRasi = 4
            content = AnyView(HStack(spacing: 20) {
                SheetFace(context: context, layout: draft.layout, extras: sample).environment(\.cardTheme, t)
                SheetFace(context: context, layout: draft.layout, extras: nil).environment(\.cardTheme, CardTheme(scale: 1, language: language))
            }.padding(20))
        }

        let renderer = ImageRenderer(content: content.background(Color(white: 0.85)))
        renderer.scale = 2
        guard let image = renderer.cgImage,
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else { return }
        try? data.write(to: url)
    }
}
private extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}
#endif
