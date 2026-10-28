#if DEBUG
import AppKit
import RasiCore
import SwiftUI

/// Debug helper: `RasiPalan -snapshot /path/out.png` renders the pad to a PNG and quits,
/// so the visuals can be checked without screen-recording access.
/// Optional: `-snapshotDay 2026-09-18`, `-snapshotStyle precise`, `-snapshotLanguage english`, `-snapshotScale 2`, `-snapshotPaper dark`, `-snapshotBinColors 1`.
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
        model.paperChoice = defaults.string(forKey: "snapshotPaper").flatMap(PaperChoice.init(rawValue:)) ?? .template
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

        // -snapshotWear 1: a sheet left on the pad until late evening, the next morning, 3 and 4 days,
        // a week and a month.
        if defaults.double(forKey: "snapshotWear") > 0 {
            let start = day.date(hour: 0)
            content = AnyView(HStack(spacing: 0) {
                ForEach([0.95, 1.35, 3.0, 4.0, 7.0, 30.0], id: \.self) { days in
                    SheetFace(context: context, layout: model.layout,
                              wear: AppController.wear(day: day, now: start.addingTimeInterval(days * 86_400)))
                        .shadow(color: .black.opacity(0.3), radius: 6, y: 4)
                        .padding(10)
                }
            }.background(Color(white: 0.55)).environment(\.cardTheme, theme))
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

        // -snapshotBinColors 1: a part-full bin in each colour.
        if defaults.double(forKey: "snapshotBinColors") > 0 {
            let sprites = BallSprites.make(model: model)
            let binSize = TrashBinController.windowSize(scale: 1)
            content = AnyView(HStack(spacing: 0) {
                ForEach(BinColor.allCases, id: \.self) { color in
                    let bin = BinModel()
                    let _ = (bin.count = 4, bin.color = color)
                    TrashBinView(model: bin, scale: 1, sprites: sprites)
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
            if let name = defaults.string(forKey: "snapshotPalette"),
               let preset = BoardPalette.presets.first(where: { $0.name.lowercased() == name.lowercased() }) {
                model.boardPalette = preset.palette
            }
            if let motif = defaults.string(forKey: "snapshotMotif").flatMap(BoardMotif.init(rawValue:)) {
                model.boardPalette.motif = motif
            }
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
                weather: PrintedWeather(code: 95, high: 31.4, low: 24.6, rain: 70, humidity: 84))
            var t = theme
            t.myRasi = 4
            content = AnyView(HStack(spacing: 20) {
                SheetFace(context: context, layout: draft.layout, extras: sample).environment(\.cardTheme, t)
                SheetFace(context: context, layout: draft.layout, extras: nil).environment(\.cardTheme, CardTheme(scale: 1, language: language))
            }.padding(20))
        }

        // -snapshotLists 1: nine reminders under the dates, and reminders beside the English date.
        if defaults.double(forKey: "snapshotLists") > 0 {
            let sample = DayExtras(
                reminders: ["Meet Paul about knee rehab using body scan", "Submit G x R paper to Scientific Reports",
                            "Get appointment for flu vaccine", "Follow up with curriculum email", "Book Appa’s ticket",
                            "Fill interview - Camille", "Call Andrew from reform", "Look at Jay’s gift",
                            "Recheck the excel sheet"],
                events: [PrintedEvent(time: "9.30", title: "Team standup")],
                weather: PrintedWeather(code: 1, high: 36.2, low: 28.4, rain: 20, humidity: 62, now: 31.6, nowCode: 0))
            let below = LayoutDraft(from: .classic)
            below.header = .twoColumn
            below.items = [.init(type: RemindersBlock.type), .init(type: EventsBlock.type)]
            below.footer = true
            let beside = LayoutDraft(from: .classic)
            beside.header = .twoColumn
            beside.headerRight = .init(type: RemindersBlock.type)
            let weather = LayoutDraft(from: .classic)
            weather.header = .twoColumn
            weather.headerRight = .init(type: WeatherBlock.type)
            weather.items = [.init(type: RemindersBlock.type), .init(type: WeatherBlock.type)]
            weather.footer = true
            beside.items = [.init(type: PanchangamBlock.type), .init(type: TimingsBlock.type), .init(type: EventsBlock.type)]
            beside.footer = true
            content = AnyView(HStack(spacing: 20) {
                SheetFace(context: context, layout: below.layout, extras: sample)
                SheetFace(context: context, layout: beside.layout, extras: sample)
                SheetFace(context: context, layout: weather.layout, extras: sample)
            }.environment(\.cardTheme, theme).padding(20))
        }

        // -snapshotGallery 1: the Templates & Board window at its default width and its narrowest.
        if defaults.double(forKey: "snapshotGallery") > 0 {
            model.boardPhotos = state.boardPhotos
            model.boardPhotoID = state.boardPhotos.first?.id
            model.pictureChange = state.pictureChange
            model.pictureShortcut = state.pictureShortcut
            content = AnyView(HStack(alignment: .top, spacing: 20) {
                ForEach([900, 560] as [CGFloat], id: \.self) { width in
                    TemplateGalleryView(model: model, chooseLayout: { _ in }, chooseBoard: { _ in },
                                        pictures: BoardPictureActions(), customize: {}, setPalette: { _ in },
                                        customLayout: { state.customLayout }, scrolls: false)
                        .frame(width: width)
                        .background(Color.white)
                }
            }.padding(20))
        }

        // -snapshotBlank 1: everything unchecked, next to a sheet with only a note and a Western horoscope.
        if defaults.double(forKey: "snapshotBlank") > 0 {
            let blank = LayoutDraft(from: .classic)
            blank.header = .none
            blank.footer = false
            for i in blank.items.indices { blank.items[i].enabled = false }
            let mine = LayoutDraft(from: .classic)
            mine.header = .bigDate
            mine.footer = false
            mine.items = [.init(type: NoteBlock.type, params: ["text": "Call Amma at 7", "ink": "red"]),
                          .init(type: HoroscopeBlock.type)]
            var t = theme
            t.myRasi = 7
            t.signNames = .western
            content = AnyView(HStack(spacing: 20) {
                SheetFace(context: context, layout: blank.layout).environment(\.cardTheme, theme)
                SheetFace(context: context, layout: mine.layout).environment(\.cardTheme, t)
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
