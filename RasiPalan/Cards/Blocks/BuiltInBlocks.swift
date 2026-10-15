import RasiCore
import SwiftUI

private let englishWeekdays = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

/// Left column of the Classic top: "அக்டோபர் 2026", huge date, "THU".
struct GregorianDateBlock: CardBlock {
    static let type = "gregorianDate"
    static let displayName = "Date (English)"
    let context: BlockContext
    init(_ context: BlockContext) { self.context = context }
    @Environment(\.cardTheme) private var theme

    var body: some View {
        let c = context.day
        VStack(spacing: 0) {
            if theme.language == .english {
                Text("\(c.gregorianMonth.en.uppercased()) \(String(c.day.year))").font(theme.latin(11.5))
            } else {
                Text("\(c.gregorianMonth.ta) \(String(c.day.year))").font(theme.tamil(13))
            }
            Text("\(c.day.day)")
                .font(theme.numeral(104))
                .scaleEffect(x: 0.84, y: 1)   // condensed, like calendar-press numerals
                .lineLimit(1)
                .fixedSize()
                .padding(.top, theme.u(-4))
            Group {
                if theme.language == .tamil {
                    Text(c.weekday.ta).font(theme.tamil(20, bold: true))
                } else {
                    Text(englishWeekdays[c.day.weekday - 1]).font(theme.latin(25, bold: true))
                }
            }
            .padding(.top, theme.u(-10))
        }
        .padding(.top, theme.u(12))
    }
}

/// Right column of the Classic top: Tamil year, month, day and weekday.
struct TamilDateBlock: CardBlock {
    static let type = "tamilDate"
    static let displayName = "Date (Tamil)"
    let context: BlockContext
    init(_ context: BlockContext) { self.context = context }
    @Environment(\.cardTheme) private var theme

    var body: some View {
        let c = context.day
        VStack(spacing: theme.u(2)) {
            theme.label(c.tamil.yearName, 13)
            theme.label(c.tamil.month, 16, bold: true)
            Text("\(c.tamil.day)")
                .font(theme.numeral(54))
                .scaleEffect(x: 0.9, y: 1)
                .padding(.vertical, theme.u(2))
            theme.label(c.weekday, 21, bold: true)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.top, theme.u(12))
    }
}

/// "ராகு 1.30-3   குளிகை 9-10.30   எமகண்டம் 6-7.30". Params: `only` = "rahu" for Rahu Kalam alone.
struct TimingsBlock: CardBlock {
    static let type = "timings"
    static let displayName = "Rahu Kalam & timings"
    let context: BlockContext
    init(_ context: BlockContext) { self.context = context }
    @Environment(\.cardTheme) private var theme

    var body: some View {
        let c = context.day
        let t = c.timings
        // Longest times (precise style) step down a size rather than getting cut off.
        ViewThatFits(in: .horizontal) {
            ForEach([1.0, 0.88, 0.76, 0.66] as [CGFloat], id: \.self) { k in
                HStack(spacing: theme.u(12 * k)) {
                    item(Names.rahuKalam, c.range(t.rahuKalam), k)
                    if context.params["only"] != "rahu" {
                        item(Names.kuligai, c.range(t.kuligai), k)
                        item(Names.yamagandam, c.range(t.yamagandam), k)
                    }
                }
                .lineLimit(1)
                .fixedSize()
            }
        }
        .padding(.horizontal, theme.u(10))
    }

    private func item(_ name: LocalizedText, _ value: String, _ k: CGFloat) -> some View {
        HStack(spacing: theme.u(4 * k)) {
            theme.label(name, 12.5 * k, bold: true)
            Text(value).font(theme.latin(11.5 * k, bold: true))
        }
    }
}

/// Sunrise, sunset and Soolam (inauspicious direction).
struct SunTimesBlock: CardBlock {
    static let type = "sunTimes"
    static let displayName = "Sunrise & sunset"
    let context: BlockContext
    init(_ context: BlockContext) { self.context = context }
    @Environment(\.cardTheme) private var theme

    var body: some View {
        let c = context.day
        HStack(spacing: theme.u(12)) {
            if let rise = c.sunrise, let set = c.sunset {
                pair(Names.sunrise, c.clock(rise))
                pair(Names.sunset, c.clock(set))
            }
            HStack(spacing: theme.u(3)) {
                theme.label(Names.soolam, 11)
                theme.label(c.timings.soolam, 11)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .padding(.horizontal, theme.u(10))
    }

    private func pair(_ name: LocalizedText, _ value: String) -> some View {
        HStack(spacing: theme.u(3)) {
            theme.label(name, 11)
            Text(value).font(theme.latin(10))
        }
    }
}

/// Faint placeholder for data that arrives in a later milestone.
struct ComingSoonBlock: CardBlock {
    static let type = "comingSoon"
    static let displayName = "Placeholder"
    let context: BlockContext
    init(_ context: BlockContext) { self.context = context }
    @Environment(\.cardTheme) private var theme

    var body: some View {
        Text(context.params["text"] ?? "")
            .font(theme.latin(8.5).italic())
            .foregroundStyle(Ink.faded)
            .multilineTextAlignment(.center)
            .padding(.horizontal, theme.u(14))
    }
}

/// Static text printed on the sheet. Basis for future to-do / events / notes blocks.
/// Params: `text`, optional `ink` ("red" | "black"), optional `size` (points).
struct NoteBlock: CardBlock {
    static let type = "note"
    static let displayName = "Note"
    let context: BlockContext
    init(_ context: BlockContext) { self.context = context }
    @Environment(\.cardTheme) private var theme

    var body: some View {
        let text = context.params["text"] ?? ""
        let size = context.params["size"].flatMap(Double.init).map { CGFloat($0) } ?? 11
        let isTamil = text.unicodeScalars.contains { (0x0B80...0x0BFF).contains($0.value) }
        Text(text)
            .font(isTamil ? theme.tamil(size) : theme.latin(size * 0.9))
            .foregroundStyle(context.params["ink"] == "red" ? Ink.red : Ink.black)
            .multilineTextAlignment(.center)
            .padding(.horizontal, theme.u(12))
    }
}

/// Bottom line in red: place the sheet was reckoned for, and the panchangam style.
struct FooterBlock: CardBlock {
    static let type = "footer"
    static let displayName = "Footer"
    let context: BlockContext
    init(_ context: BlockContext) { self.context = context }
    @Environment(\.cardTheme) private var theme

    var body: some View {
        let c = context.day
        let style = c.style == .traditional
            ? LocalizedText(ta: "வாக்கியம்", en: "Vakyam")
            : LocalizedText(ta: "திருக்கணிதம்", en: "Thirukanitham")
        HStack {
            Text(c.location.name).font(theme.latin(8.5))
            Spacer()
            theme.label(style, 9.5)
        }
        .foregroundStyle(Ink.red)
        .padding(.horizontal, theme.u(14))
        .padding(.bottom, theme.u(10))
    }
}

/// Centred, oversized date for sparse templates: month line, huge number, weekday.
/// Params: `size` (numeral points, default 150).
struct BigDateBlock: CardBlock {
    static let type = "bigDate"
    static let displayName = "Big date"
    let context: BlockContext
    init(_ context: BlockContext) { self.context = context }
    @Environment(\.cardTheme) private var theme

    var body: some View {
        let c = context.day
        let size = context.params["size"].flatMap(Double.init).map { CGFloat($0) } ?? 150
        VStack(spacing: 0) {
            Group {
                if theme.language == .english {
                    Text("\(c.gregorianMonth.en.uppercased()) \(String(c.day.year))").font(theme.latin(12))
                } else {
                    Text("\(c.gregorianMonth.ta) \(String(c.day.year))").font(theme.tamil(14))
                }
            }
            .foregroundStyle(Ink.red)
            Text("\(c.day.day)")
                .font(theme.numeral(size))
                .scaleEffect(x: 0.84, y: 1)
                .lineLimit(1)
                .fixedSize()
                .padding(.top, theme.u(-size * 0.06))
            Group {
                if theme.language == .english {
                    Text(c.weekday.en.uppercased()).font(theme.latin(22, bold: true))
                } else {
                    Text(c.weekday.ta).font(theme.tamil(24, bold: true))
                }
            }
            .padding(.top, theme.u(-size * 0.1))
        }
        .padding(.top, theme.u(14))
    }
}

/// One line of Tamil date: "புரட்டாசி 28 · பராபவ".
struct TamilDateLineBlock: CardBlock {
    static let type = "tamilDateLine"
    static let displayName = "Tamil date (one line)"
    let context: BlockContext
    init(_ context: BlockContext) { self.context = context }
    @Environment(\.cardTheme) private var theme

    var body: some View {
        let t = context.day.tamil
        HStack(spacing: theme.u(6)) {
            theme.label(t.month, 14, bold: true)
            Text("\(t.day)").font(theme.latin(14, bold: true))
            Text("·").font(theme.latin(14))
            theme.label(t.yearName, 13)
        }
    }
}

/// The day's one-word Rasi Palan for all 12 rasis, in a grid.
struct RasiPalanBlock: CardBlock {
    static let type = "rasiPalan"
    static let displayName = "Rasi Palan"
    let context: BlockContext
    init(_ context: BlockContext) { self.context = context }
    @Environment(\.cardTheme) private var theme

    var body: some View {
        let words = RasiPalan.words(for: context.day.day)
        VStack(spacing: theme.u(3)) {
            theme.label(LocalizedText(ta: "இன்றைய ராசி பலன்", en: "Today's Rasi Palan"), 10.5, bold: true)
                .foregroundStyle(Ink.red)
            Grid(horizontalSpacing: theme.u(8), verticalSpacing: theme.u(2.5)) {
                ForEach(0..<4, id: \.self) { row in
                    GridRow {
                        ForEach(0..<3, id: \.self) { col in
                            let i = row * 3 + col
                            HStack(spacing: theme.u(2)) {
                                theme.label(RasiPalan.rasis[i], 9.5, bold: true)
                                Text("–").font(theme.latin(8))
                                theme.label(words[i], 9.5)
                            }
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, theme.u(10))
    }
}

/// A short horizontal rule. Params: `width` (share of the sheet, default 0.9).
struct RuleBlock: CardBlock {
    static let type = "rule"
    static let displayName = "Rule"
    let context: BlockContext
    init(_ context: BlockContext) { self.context = context }
    @Environment(\.cardTheme) private var theme

    var body: some View {
        let share = context.params["width"].flatMap(Double.init).map { CGFloat($0) } ?? 0.9
        Rectangle().fill(context.params["ink"] == "red" ? Ink.red : Ink.black)
            .frame(width: theme.u(PadView.sheetSize.width) * share, height: max(1, theme.u(1)))
    }
}

/// "பஞ்சமி நள்ளிரவு கடந்து 3.10 வரை    கேட்டை நாள் முழுவதும்", then the yogam centred below.
struct PanchangamBlock: CardBlock {
    static let type = "panchangam"
    static let displayName = "Tithi, star & yogam"
    let context: BlockContext
    init(_ context: BlockContext) { self.context = context }
    @Environment(\.cardTheme) private var theme

    var body: some View {
        let c = context.day, p = c.panchangam
        VStack(spacing: theme.u(2)) {
            ViewThatFits(in: .horizontal) {
                ForEach([1.0, 0.88, 0.76, 0.66] as [CGFloat], id: \.self) { k in
                    HStack(spacing: theme.u(12 * k)) {
                        span(p.tithi, k)
                        span(p.nakshatra, k)
                    }
                    .fixedSize()
                }
            }
            if context.params["yogam"] != "hide" {
                theme.label(p.yogam, 11)
            }
        }
        .padding(.horizontal, theme.u(10))
    }

    private func span(_ s: Panchangam.Span, _ k: CGFloat) -> some View {
        let c = context.day
        return HStack(spacing: theme.u(3 * k)) {
            theme.label(s.name, 11.5 * k, bold: true)
            theme.label(c.until(s), 10.5 * k)
        }
    }
}

/// Festivals and notable days, then the day's direction ("↔ சமநோக்கு நாள்").
struct ObservancesBlock: CardBlock {
    static let type = "observances"
    static let displayName = "Festivals & observances"
    let context: BlockContext
    init(_ context: BlockContext) { self.context = context }
    @Environment(\.cardTheme) private var theme

    var body: some View {
        let c = context.day
        let joined = c.observances.map { theme.text($0) }.joined(separator: " ; ")
        VStack(spacing: theme.u(2)) {
            if !joined.isEmpty {
                Text(joined)
                    .font(theme.language == .english ? theme.latin(10) : theme.tamil(11))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            if context.params["direction"] != "hide" {
                theme.label(Names.directions3[c.panchangam.direction.rawValue], 10.5)
            }
        }
        .padding(.horizontal, theme.u(12))
    }
}

/// Red "நல்ல நேரம்: 10.30-11  1-1.30", optionally with chandrashtamam.
struct NallaNeramBlock: CardBlock {
    static let type = "nallaNeram"
    static let displayName = "Good times"
    let context: BlockContext
    init(_ context: BlockContext) { self.context = context }
    @Environment(\.cardTheme) private var theme

    var body: some View {
        let c = context.day, p = c.panchangam
        VStack(spacing: theme.u(3)) {
            if context.params["chandrashtamam"] != "hide" {
                HStack(spacing: theme.u(4)) {
                    theme.label(Names.chandrashtamam, 10.5)
                    Text(":").font(theme.latin(10))
                    theme.label(LocalizedText(ta: p.chandrashtamam.map(\.ta).joined(separator: ", "),
                                              en: p.chandrashtamam.map(\.en).joined(separator: ", ")), 10.5)
                }
            }
            HStack(spacing: theme.u(6)) {
                theme.label(Names.nallaNeram, 12, bold: true)
                Text(":").font(theme.latin(11))
                ForEach(Array(p.nallaNeram.enumerated()), id: \.offset) { _, span in
                    Text(c.range(span)).font(theme.latin(11, bold: true))
                }
            }
            .foregroundStyle(Ink.red)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, theme.u(10))
    }
}

/// The day's Thirukkural couplet (or its meaning, on English cards).
struct KuralBlock: CardBlock {
    static let type = "kural"
    static let displayName = "Thirukkural"
    let context: BlockContext
    init(_ context: BlockContext) { self.context = context }
    @Environment(\.cardTheme) private var theme

    var body: some View {
        let k = context.day.kural
        VStack(spacing: theme.u(3)) {
            if theme.language == .english {
                Text("“\(k.meaning)”").font(theme.latin(10).italic())
                Text("Thirukkural \(k.number)").font(theme.latin(8)).foregroundStyle(Ink.red)
            } else {
                Text(k.tamil).font(theme.tamil(10.5))
                Text("திருக்குறள் \(k.number)").font(theme.tamil(8.5)).foregroundStyle(Ink.red)
            }
        }
        .multilineTextAlignment(.center)
        .lineLimit(3)
        .minimumScaleFactor(0.75)
        .padding(.horizontal, theme.u(16))
    }
}
