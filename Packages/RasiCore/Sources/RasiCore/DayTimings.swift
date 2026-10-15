import Foundation

/// A span of clock time, e.g. Rahu Kalam 1:30–3:00.
public struct TimeSpan: Hashable, Sendable {
    public var start: Date
    public var end: Date
}

/// Rahu Kalam, Yamagandam and Kuligai. Each is one of the eight equal parts of daytime,
/// and which part depends on the weekday.
public struct DayTimings: Hashable, Sendable {
    public var rahuKalam: TimeSpan
    public var yamagandam: TimeSpan
    public var kuligai: TimeSpan
    /// Inauspicious direction for travel today.
    public var soolam: LocalizedText

    // 1-based part of the day (of 8), indexed by weekday (Sunday first).
    static let rahuPart = [8, 2, 7, 5, 6, 4, 3]
    static let yamagandamPart = [5, 4, 3, 2, 1, 7, 6]
    static let kuligaiPart = [7, 6, 5, 4, 3, 2, 1]
    // Index into Names.directions (East, South, West, North).
    static let soolamDirection = [2, 0, 3, 3, 1, 2, 0]

    /// Traditional: the fixed times printed on wall calendars, assuming a 6 AM–6 PM day.
    /// Precise: actual sunrise to sunset (falls back to 6–6 during polar day/night).
    public init(day: CalendarDay, sunrise: Date?, sunset: Date?, style: PanchangamStyle, timeZone: TimeZone) {
        let start: Date, end: Date
        if style == .precise, let sunrise, let sunset {
            start = sunrise
            end = sunset
        } else {
            start = day.date(hour: 6, in: timeZone)
            end = day.date(hour: 18, in: timeZone)
        }
        let part = end.timeIntervalSince(start) / 8
        func span(_ n: Int) -> TimeSpan {
            let s = start.addingTimeInterval(Double(n - 1) * part)
            return TimeSpan(start: s, end: s.addingTimeInterval(part))
        }
        let w = day.weekday - 1
        rahuKalam = span(Self.rahuPart[w])
        yamagandam = span(Self.yamagandamPart[w])
        kuligai = span(Self.kuligaiPart[w])
        soolam = Names.directions[Self.soolamDirection[w]]
    }
}
