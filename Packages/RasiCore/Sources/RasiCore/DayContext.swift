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

    public init(day: CalendarDay, location: GeoLocation, style: PanchangamStyle = .traditional) {
        self.day = day
        self.location = location
        self.style = style
        tamil = TamilCalendar.date(for: day, at: location, style: style)
        sunrise = Astronomy.sunEvent(.rise, on: day, at: location)
        sunset = Astronomy.sunEvent(.set, on: day, at: location)
        timings = DayTimings(day: day, sunrise: sunrise, sunset: sunset,
                             style: style, timeZone: location.timeZone)
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
