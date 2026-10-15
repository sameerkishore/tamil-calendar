import RasiCore
import SwiftUI

/// Small red heading used by the personal blocks.
private struct BlockHeading: View {
    let text: LocalizedText
    @Environment(\.cardTheme) private var theme

    var body: some View {
        theme.label(text, 10, bold: true).foregroundStyle(Ink.red)
    }
}

/// Faint line for "nothing to show" / "needs permission".
private struct FaintLine: View {
    let text: LocalizedText
    @Environment(\.cardTheme) private var theme

    var body: some View {
        theme.label(text, 9.5).foregroundStyle(Ink.faded)
    }
}

/// Two lines of the day's palan for the user's own rasi (chosen in Settings).
struct HoroscopeBlock: CardBlock {
    static let type = "horoscope"
    static let displayName = "My horoscope (2 lines)"
    let context: BlockContext
    init(_ context: BlockContext) { self.context = context }
    @Environment(\.cardTheme) private var theme

    var body: some View {
        VStack(spacing: theme.u(2)) {
            if let rasi = theme.myRasi {
                if theme.signNames == .western {
                    Text("\(Zodiac.symbols[rasi]) \(Zodiac.western[rasi])")
                        .font(theme.latin(9.5, bold: true))
                        .foregroundStyle(Ink.red)
                } else {
                    BlockHeading(text: LocalizedText(ta: "உங்கள் ராசி: " + RasiPalan.rasis[rasi].ta,
                                                     en: "Your rasi: " + RasiPalan.rasis[rasi].en))
                }
                ForEach(Horoscope.lines(for: context.day.day, rasi: rasi), id: \.self) { line in
                    theme.label(line, 11)
                }
            } else {
                FaintLine(text: LocalizedText(ta: "அமைப்புகளில் உங்கள் ராசியைத் தேர்ந்தெடுக்கவும்",
                                              en: "Choose your sign in Settings"))
            }
        }
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.75)
        .padding(.horizontal, theme.u(12))
    }
}

/// Reminders due on the sheet's day, printed as a plain list. Params: `max` (default 10).
struct RemindersBlock: CardBlock {
    static let type = "reminders"
    static let displayName = "Reminders due"
    let context: BlockContext
    init(_ context: BlockContext) { self.context = context }
    @Environment(\.cardTheme) private var theme
    @Environment(\.sheetExtras) private var extras

    var body: some View {
        let limit = context.params["max"].flatMap(Int.init) ?? ListSize.defaultMax
        let size = ListSize(count: min(extras?.reminders?.count ?? 0, limit))
        VStack(spacing: theme.u(size.spacing)) {
            BlockHeading(text: LocalizedText(ta: "இன்று செய்ய வேண்டியவை", en: "To do"))
            if let items = extras?.reminders {
                if items.isEmpty {
                    FaintLine(text: LocalizedText(ta: "ஒன்றும் இல்லை", en: "Nothing due"))
                }
                ForEach(Array(items.prefix(limit).enumerated()), id: \.offset) { _, title in
                    line("• " + title, size: size.text)
                }
                if items.count > limit {
                    FaintLine(text: LocalizedText(ta: "மேலும் \(items.count - limit)", en: "and \(items.count - limit) more"))
                }
            } else {
                FaintLine(text: LocalizedText(ta: "நினைவூட்டல்கள் அனுமதி தேவை", en: "Allow Reminders in Settings"))
            }
        }
        .padding(.horizontal, theme.u(12))
    }

    private func line(_ text: String, size: CGFloat) -> some View {
        Text(text)
            .font(PersonalText.font(for: text, theme: theme, size: size))
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Calendar events on the sheet's day, from the calendars chosen in Settings.
/// Params: `max` (default 10).
struct EventsBlock: CardBlock {
    static let type = "events"
    static let displayName = "Calendar events"
    let context: BlockContext
    init(_ context: BlockContext) { self.context = context }
    @Environment(\.cardTheme) private var theme
    @Environment(\.sheetExtras) private var extras

    var body: some View {
        let limit = context.params["max"].flatMap(Int.init) ?? ListSize.defaultMax
        let size = ListSize(count: min(extras?.events?.count ?? 0, limit))
        VStack(spacing: theme.u(size.spacing)) {
            BlockHeading(text: LocalizedText(ta: "இன்றைய நிகழ்வுகள்", en: "Events"))
            if let items = extras?.events {
                if items.isEmpty {
                    FaintLine(text: LocalizedText(ta: "நிகழ்வுகள் இல்லை", en: "No events"))
                }
                ForEach(Array(items.prefix(limit).enumerated()), id: \.offset) { _, event in
                    HStack(alignment: .firstTextBaseline, spacing: theme.u(6)) {
                        Group {
                            if let time = event.time {
                                Text(time).font(theme.latin(size.text - 1, bold: true))
                            } else {
                                theme.label(LocalizedText(ta: "முழு நாள்", en: "All day"), size.text - 1.5, bold: true)
                            }
                        }
                        .frame(width: theme.u(40), alignment: .trailing)
                        Text(event.title)
                            .font(PersonalText.font(for: event.title, theme: theme, size: size.text))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 0)
                    }
                }
                if items.count > limit {
                    FaintLine(text: LocalizedText(ta: "மேலும் \(items.count - limit)", en: "and \(items.count - limit) more"))
                }
            } else {
                FaintLine(text: LocalizedText(ta: "நாட்காட்டி அனுமதி தேவை", en: "Allow Calendars in Settings"))
            }
        }
        .padding(.horizontal, theme.u(12))
    }
}

/// The day's forecast for the sheet's city, in one printed line. Params: `size` = "big" prints
/// the temperature as a big numeral, for the box beside the date: the current temperature on
/// today's sheet, the day's high on others.
struct WeatherBlock: CardBlock {
    static let type = "weather"
    static let displayName = "Weather"
    let context: BlockContext
    init(_ context: BlockContext) { self.context = context }
    @Environment(\.cardTheme) private var theme
    @Environment(\.sheetExtras) private var extras

    var body: some View {
        if context.params["size"] == "big" { big } else { line }
    }

    private var big: some View {
        VStack(spacing: theme.u(2)) {
            if let w = extras?.weather {
                Image(systemName: w.symbol)
                    .font(.system(size: theme.u(24), weight: .semibold))
                    .frame(height: theme.u(30))
                theme.label(w.description, 13)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(Int((w.now ?? w.high).rounded()))°")
                    .font(theme.numeral(54))
                    .scaleEffect(x: 0.9, y: 1)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.vertical, theme.u(2))
                Text("\(Int(w.high.rounded()))° / \(Int(w.low.rounded()))°").font(theme.latin(13, bold: true))
                if let rain = w.rain, rain >= 20 {
                    theme.label(LocalizedText(ta: "மழை \(rain)%", en: "rain \(rain)%"), 11)
                }
            } else {
                FaintLine(text: LocalizedText(ta: "வானிலை கிடைக்கவில்லை", en: "No forecast for this day"))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, theme.u(8))
    }

    private var line: some View {
        Group {
            if let w = extras?.weather {
                HStack(spacing: theme.u(5)) {
                    Image(systemName: w.symbol)
                        .font(.system(size: theme.u(14), weight: .semibold))
                    Text("\(Int(w.high.rounded()))° / \(Int(w.low.rounded()))°").font(theme.latin(11, bold: true))
                    theme.label(w.description, 10.5)
                    if let rain = w.rain, rain >= 20 {
                        theme.label(LocalizedText(ta: "மழை \(rain)%", en: "rain \(rain)%"), 10)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            } else {
                FaintLine(text: LocalizedText(ta: "வானிலை கிடைக்கவில்லை", en: "No forecast for this day"))
            }
        }
        .padding(.horizontal, theme.u(12))
    }
}

/// Lists print smaller as they grow, so ten items still fit on the sheet.
struct ListSize {
    static let defaultMax = 10
    let text: CGFloat
    let spacing: CGFloat

    init(count: Int) {
        switch count {
        case ...4: (text, spacing) = (10.5, 1.5)
        case 5...6: (text, spacing) = (9.5, 1)
        default: (text, spacing) = (8.5, 0.5)
        }
    }
}

/// User text may be Tamil or English; set it in the matching typeface.
enum PersonalText {
    static func font(for text: String, theme: CardTheme, size: CGFloat) -> Font {
        let tamil = text.unicodeScalars.contains { (0x0B80...0x0BFF).contains($0.value) }
        return tamil ? theme.tamil(size) : theme.latin(size * 0.9)
    }
}
