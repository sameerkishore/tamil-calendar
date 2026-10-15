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

/// "ராகு 1.30-3   குளிகை 9-10.30   எமகண்டம் 6-7.30"
struct TimingsBlock: CardBlock {
    static let type = "timings"
    static let displayName = "Rahu Kalam & timings"
    let context: BlockContext
    init(_ context: BlockContext) { self.context = context }
    @Environment(\.cardTheme) private var theme

    var body: some View {
        let c = context.day
        let t = c.timings
        HStack(spacing: theme.u(12)) {
            item(Names.rahuKalam, c.range(t.rahuKalam))
            item(Names.kuligai, c.range(t.kuligai))
            item(Names.yamagandam, c.range(t.yamagandam))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .padding(.horizontal, theme.u(10))
    }

    private func item(_ name: LocalizedText, _ value: String) -> some View {
        HStack(spacing: theme.u(4)) {
            theme.label(name, 12.5, bold: true)
            Text(value).font(theme.latin(11.5, bold: true))
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
