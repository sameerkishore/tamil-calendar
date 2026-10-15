import Foundation

/// Everything a card needs to print one day's sheet. Card blocks read from this and
/// nothing else, so new data (panchangam, weather, to-dos…) is added here.
public struct DayContext: Hashable, Sendable {
    public var day: CalendarDay
    public var location: GeoLocation
    public var tamil: TamilDate
    public var sunrise: Date?
    public var sunset: Date?
    public var timings: DayTimings
    public var style: PanchangamStyle
    public var panchangam: Panchangam
    public var observances: [LocalizedText]
    /// Sundays and holidays: the date prints in red.
    public var isRedLetter: Bool
    public var kural: Kural

    public init(day: CalendarDay, location: GeoLocation, style: PanchangamStyle = .traditional) {
        self.day = day
        self.location = location
        self.style = style
        tamil = TamilCalendar.date(for: day, at: location, style: style)
        sunrise = Astronomy.sunEvent(.rise, on: day, at: location)
        sunset = Astronomy.sunEvent(.set, on: day, at: location)
        timings = DayTimings(day: day, sunrise: sunrise, sunset: sunset,
                             style: style, timeZone: location.timeZone)
        panchangam = Panchangam(day: day, location: location, sunrise: sunrise)
        let found = Observances.list(day: day, tamil: tamil,
                                     nextTamil: TamilCalendar.date(for: day.adding(days: 1), at: location, style: style),
                                     panchangam: panchangam)
        observances = found.items
        isRedLetter = day.weekday == 1 || found.holiday
        kural = Kural.of(day)
    }

    /// When a tithi or star ends, worded the way calendars print it:
    /// "நாள் முழுவதும்" (all day), "நள்ளிரவு கடந்து 3.10 வரை" (till 3.10 past midnight), "மாலை 5.20 வரை".
    public func until(_ span: Panchangam.Span) -> LocalizedText {
        guard span.next != nil else { return LocalizedText(ta: "நாள் முழுவதும்", en: "all day") }
        let t = clock(span.ends)
        if CalendarDay(containing: span.ends, in: location.timeZone) != day {
            return LocalizedText(ta: "நள்ளிரவு கடந்து \(t) வரை", en: "till \(t) after midnight")
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = location.timeZone
        let hour = cal.component(.hour, from: span.ends)
        let part = hour < 12 ? "காலை" : hour < 16 ? "பகல்" : hour < 19 ? "மாலை" : "இரவு"
        return LocalizedText(ta: "\(part) \(t) வரை", en: "till \(t) \(hour < 12 ? "am" : "pm")")
    }

    public var weekday: LocalizedText { Names.weekdays[day.weekday - 1] }
    public var gregorianMonth: LocalizedText { Names.gregorianMonths[day.month - 1] }

    /// Calendar-style clock time: 12-hour, dot separator, minutes dropped on the hour ("1.30", "3").
    public func clock(_ date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = location.timeZone
        let c = cal.dateComponents([.hour, .minute], from: date)
        let h = (c.hour! + 11) % 12 + 1
        return c.minute! == 0 ? "\(h)" : String(format: "%d.%02d", h, c.minute!)
    }

    /// "1.30-3"
    public func range(_ span: TimeSpan) -> String {
        "\(clock(span.start))-\(clock(span.end))"
    }
}
