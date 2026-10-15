import Foundation

/// The day's almanac details, reckoned at sunrise as Tamil calendars do.
/// Aimed at looking right on the sheet rather than at almanac-grade precision.
public struct Panchangam: Hashable, Sendable {
    /// A tithi or nakshatra and when it ends.
    public struct Span: Hashable, Sendable {
        public var name: LocalizedText
        public var ends: Date
        /// What follows, if it changes before the next sunrise.
        public var next: LocalizedText?
    }

    public enum Direction: Int, Sendable { case level, upward, downward }

    public var tithi: Span
    /// 0…29 (0 = Shukla Prathamai, 14 = Pournami, 29 = Amavasai).
    public var tithiIndex: Int
    public var nakshatra: Span
    /// 0…26 (0 = Ashwini).
    public var nakshatraIndex: Int
    public var yogam: LocalizedText
    public var direction: Direction
    /// Stars for whom today is chandrashtamam.
    public var chandrashtamam: [LocalizedText]
    public var nallaNeram: [TimeSpan]

    public init(day: CalendarDay, location: GeoLocation, sunrise: Date?) {
        let tz = location.timeZone
        let rise = sunrise ?? day.date(hour: 6, in: tz)
        let nextRise = Astronomy.sunEvent(.rise, on: day.adding(days: 1), at: location) ?? rise.addingTimeInterval(86_400)

        let ti = Int(Astronomy.elongation(at: rise) / 12) % 30
        let tiEnd = Astronomy.timeWhen(Astronomy.elongation, reaches: Double(ti + 1) * 12, after: rise, rate: 12.19)
        tithiIndex = ti
        tithi = Span(name: Self.tithiName(ti), ends: tiEnd, next: tiEnd < nextRise ? Self.tithiName((ti + 1) % 30) : nil)

        let span = 360.0 / 27
        let ni = Int(Astronomy.siderealMoonLongitude(at: rise) / span) % 27
        let niEnd = Astronomy.timeWhen(Astronomy.siderealMoonLongitude, reaches: Double(ni + 1) * span, after: rise, rate: 13.18)
        nakshatraIndex = ni
        nakshatra = Span(name: Names.nakshatras[ni], ends: niEnd, next: niEnd < nextRise ? Names.nakshatras[(ni + 1) % 27] : nil)

        // Tamil yogam (amirtha / siddha / marana) depends on weekday and star. A stable stand-in
        // spread, weighted like real calendars: mostly siddha, often amirtha, sometimes marana.
        let mix = (day.weekday * 7 + ni * 3) % 20
        yogam = mix < 11 ? Names.siddhaYogam : (mix < 17 ? Names.amirthaYogam : Names.maranaYogam)

        direction = Self.upward.contains(ni) ? .upward : (Self.downward.contains(ni) ? .downward : .level)

        // The Moon is in the 8th sign from these stars' sign: roughly 16 stars back.
        chandrashtamam = [Names.nakshatras[(ni + 27 - 16) % 27], Names.nakshatras[(ni + 27 - 15) % 27]]

        nallaNeram = Self.nallaNeramTable[day.weekday - 1].map { s in
            TimeSpan(start: day.date(hour: 0, in: tz).addingTimeInterval(s.0 * 3_600),
                     end: day.date(hour: 0, in: tz).addingTimeInterval(s.1 * 3_600))
        }
    }

    static func tithiName(_ i: Int) -> LocalizedText {
        switch i {
        case 14: Names.pournami
        case 29: Names.amavasai
        default: Names.tithis[i % 15]
        }
    }

    static let upward: Set<Int> = [3, 5, 7, 11, 20, 21, 22, 23, 25]
    static let downward: Set<Int> = [1, 2, 8, 9, 10, 15, 18, 19, 24]

    /// Good times as printed on wall calendars, by weekday (Sunday first), in hours.
    static let nallaNeramTable: [[(Double, Double)]] = [
        [(7.5, 8.5), (15.5, 16.5)],
        [(6.5, 7.5), (16.5, 17.5)],
        [(7.5, 8.5), (16.5, 17.5)],
        [(9.5, 10.5), (16.5, 17.5)],
        [(10.5, 11), (13, 13.5)],
        [(6.5, 7.5), (16.5, 17.5)],
        [(7.5, 8.5), (16.5, 17.5)],
    ]
}

extension Names {
    /// Prathamai … Chaturdasi (the 15th and 30th are Pournami / Amavasai).
    public static let tithis: [LocalizedText] = [
        .init(ta: "பிரதமை", en: "Prathamai"), .init(ta: "துவிதியை", en: "Dvitiyai"),
        .init(ta: "திருதியை", en: "Tritiyai"), .init(ta: "சதுர்த்தி", en: "Chaturthi"),
        .init(ta: "பஞ்சமி", en: "Panchami"), .init(ta: "சஷ்டி", en: "Sashti"),
        .init(ta: "சப்தமி", en: "Saptami"), .init(ta: "அஷ்டமி", en: "Ashtami"),
        .init(ta: "நவமி", en: "Navami"), .init(ta: "தசமி", en: "Dasami"),
        .init(ta: "ஏகாதசி", en: "Ekadasi"), .init(ta: "துவாதசி", en: "Dvadasi"),
        .init(ta: "திரயோதசி", en: "Trayodasi"), .init(ta: "சதுர்த்தசி", en: "Chaturdasi"),
        .init(ta: "பௌர்ணமி", en: "Pournami"),
    ]
    public static let pournami = LocalizedText(ta: "பௌர்ணமி", en: "Pournami")
    public static let amavasai = LocalizedText(ta: "அமாவாசை", en: "Amavasai")

    public static let nakshatras: [LocalizedText] = [
        .init(ta: "அசுவினி", en: "Ashwini"), .init(ta: "பரணி", en: "Bharani"),
        .init(ta: "கார்த்திகை", en: "Karthigai"), .init(ta: "ரோகிணி", en: "Rohini"),
        .init(ta: "மிருகசீரிடம்", en: "Mirugaseersham"), .init(ta: "திருவாதிரை", en: "Thiruvathirai"),
        .init(ta: "புனர்பூசம்", en: "Punarpoosam"), .init(ta: "பூசம்", en: "Poosam"),
        .init(ta: "ஆயில்யம்", en: "Ayilyam"), .init(ta: "மகம்", en: "Magam"),
        .init(ta: "பூரம்", en: "Pooram"), .init(ta: "உத்திரம்", en: "Uthiram"),
        .init(ta: "அஸ்தம்", en: "Hastham"), .init(ta: "சித்திரை", en: "Chithirai"),
        .init(ta: "சுவாதி", en: "Swathi"), .init(ta: "விசாகம்", en: "Visakam"),
        .init(ta: "அனுஷம்", en: "Anusham"), .init(ta: "கேட்டை", en: "Kettai"),
        .init(ta: "மூலம்", en: "Moolam"), .init(ta: "பூராடம்", en: "Pooradam"),
        .init(ta: "உத்திராடம்", en: "Uthiradam"), .init(ta: "திருவோணம்", en: "Thiruvonam"),
        .init(ta: "அவிட்டம்", en: "Avittam"), .init(ta: "சதயம்", en: "Sadhayam"),
        .init(ta: "பூரட்டாதி", en: "Poorattadhi"), .init(ta: "உத்திரட்டாதி", en: "Uthirattadhi"),
        .init(ta: "ரேவதி", en: "Revathi"),
    ]

    public static let siddhaYogam = LocalizedText(ta: "சித்த யோகம்", en: "Siddha Yogam")
    public static let amirthaYogam = LocalizedText(ta: "அமிர்த யோகம்", en: "Amirtha Yogam")
    public static let maranaYogam = LocalizedText(ta: "மரண யோகம்", en: "Marana Yogam")
    public static let nallaNeram = LocalizedText(ta: "நல்ல நேரம்", en: "Good time")
    public static let chandrashtamam = LocalizedText(ta: "சந்திராஷ்டமம்", en: "Chandrashtamam")
    public static let directions3: [LocalizedText] = [
        .init(ta: "↔ சமநோக்கு நாள்", en: "↔ Level day"),
        .init(ta: "↑ மேல்நோக்கு நாள்", en: "↑ Upward day"),
        .init(ta: "↓ கீழ்நோக்கு நாள்", en: "↓ Downward day"),
    ]
}
