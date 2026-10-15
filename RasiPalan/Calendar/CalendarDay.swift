import Foundation

/// A plain calendar date with no time or time zone, so the pad date never drifts
/// when the user travels or the clock passes midnight.
struct CalendarDay: Codable, Hashable, Comparable {
    var year: Int
    var month: Int
    var day: Int

    static func today(calendar: Calendar = .current) -> CalendarDay {
        let c = calendar.dateComponents([.year, .month, .day], from: Date())
        return CalendarDay(year: c.year!, month: c.month!, day: c.day!)
    }

    /// Noon on this day in the given calendar, which is safe from DST edge cases.
    func date(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func adding(days: Int, calendar: Calendar = .current) -> CalendarDay {
        let d = calendar.date(byAdding: .day, value: days, to: date(calendar: calendar))!
        let c = calendar.dateComponents([.year, .month, .day], from: d)
        return CalendarDay(year: c.year!, month: c.month!, day: c.day!)
    }

    /// 1 = Sunday … 7 = Saturday.
    var weekday: Int {
        Calendar(identifier: .gregorian).component(.weekday, from: date(calendar: Calendar(identifier: .gregorian)))
    }

    var longDescription: String {
        date().formatted(.dateTime.weekday(.wide).day().month(.wide).year())
    }

    static func < (a: CalendarDay, b: CalendarDay) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }
}
