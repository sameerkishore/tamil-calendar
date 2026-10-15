import Foundation

/// A plain calendar date with no time or time zone, so the pad date never drifts
/// when the user travels or the clock passes midnight.
public struct CalendarDay: Codable, Hashable, Comparable, Sendable, CustomStringConvertible {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public static func today(in timeZone: TimeZone = .current) -> CalendarDay {
        CalendarDay(containing: Date(), in: timeZone)
    }

    /// The day on which `date` falls, as seen on a clock in `timeZone`.
    public init(containing date: Date, in timeZone: TimeZone) {
        let c = Self.gregorian(timeZone).dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year!, month: c.month!, day: c.day!)
    }

    /// The instant at `hour`:00 local time on this day.
    public func date(hour: Int = 12, in timeZone: TimeZone = .current) -> Date {
        Self.gregorian(timeZone).date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    public func adding(days: Int) -> CalendarDay {
        let utc = TimeZone(identifier: "UTC")!
        let d = Self.gregorian(utc).date(byAdding: .day, value: days, to: date(in: utc))!
        return CalendarDay(containing: d, in: utc)
    }

    /// Whole days from `self` to `other` (positive if `other` is later).
    public func days(to other: CalendarDay) -> Int {
        let utc = TimeZone(identifier: "UTC")!
        return Self.gregorian(utc).dateComponents([.day], from: date(in: utc), to: other.date(in: utc)).day!
    }

    /// 1 = Sunday … 7 = Saturday.
    public var weekday: Int {
        let utc = TimeZone(identifier: "UTC")!
        return Self.gregorian(utc).component(.weekday, from: date(in: utc))
    }

    public var longDescription: String {
        date().formatted(.dateTime.weekday(.wide).day().month(.wide).year())
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func < (a: CalendarDay, b: CalendarDay) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }

    static func gregorian(_ timeZone: TimeZone) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal
    }
}
