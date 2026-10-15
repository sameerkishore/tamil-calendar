import Foundation

/// How the panchangam is reckoned. Both are legitimate; they differ by up to a day at month
/// boundaries, so the user picks the one that matches the calendar they grew up with.
public enum PanchangamStyle: String, Codable, Sendable, CaseIterable {
    /// Vakyam: what printed Tamil Nadu wall calendars show. Months use the Surya Siddhanta Sun
    /// reckoned for Tamil Nadu, and Rahu Kalam uses the fixed 6 AM–6 PM times ("Thursday 1.30–3").
    case traditional
    /// Thirukanitham / drik: the true sky for the user's own location. Months use the modern
    /// sidereal Sun and local sunset; timings are eighths of the actual local daytime.
    case precise
}

/// A date in the Tamil solar calendar.
public struct TamilDate: Hashable, Sendable {
    /// 0 = Chithirai … 11 = Panguni.
    public var monthIndex: Int
    /// 1-based day of the Tamil month.
    public var day: Int
    /// 0 = Prabhava … 59 = Akshaya.
    public var yearIndex: Int
    /// When the Sun entered this month's rasi (the sankranti), as reckoned by the chosen style.
    public var monthStart: Date

    public var month: LocalizedText { Names.tamilMonths[monthIndex] }
    public var yearName: LocalizedText { Names.tamilYears[yearIndex] }
}

/// The Tamil month is the sidereal zodiac sign the Sun is in. A month starts on the civil day
/// of the sankranti (Sun's ingress into the sign) if that happens before sunset, otherwise
/// the next day.
public enum TamilCalendar {
    /// The traditional reckoning runs this much earlier than pure Surya Siddhanta. Fitted to
    /// 36 published month starts (2025–2027), which all match for any offset between −2.8 h and
    /// −1.8 h; the midpoint keeps about 30 minutes of margin on each side. See tests.
    static let traditionalOffset: TimeInterval = -2.3 * 3600

    public static func date(for day: CalendarDay, at location: GeoLocation,
                            style: PanchangamStyle = .traditional) -> TamilDate {
        // Printed calendars are reckoned for Tamil Nadu, wherever they hang.
        let place = style == .traditional ? GeoLocation.chennai : location
        let tz = place.timeZone

        func longitude(_ t: Date) -> Double {
            switch style {
            case .traditional: SuryaSiddhanta.solarLongitude(at: t.addingTimeInterval(-traditionalOffset))
            case .precise: Astronomy.siderealSunLongitude(at: t)
            }
        }
        func time(of target: Double, near guess: Date) -> Date {
            switch style {
            case .traditional:
                SuryaSiddhanta.timeOfSolarLongitude(target, near: guess.addingTimeInterval(-traditionalOffset))
                    .addingTimeInterval(traditionalOffset)
            case .precise:
                Astronomy.timeOfSiderealSunLongitude(target, near: guess)
            }
        }
        func sunset(_ d: CalendarDay) -> Date {
            Astronomy.sunEvent(.set, on: d, at: place) ?? d.date(hour: 18, in: tz)
        }

        // Whatever sign the Sun is in at today's sunset is today's month.
        let todaySunset = sunset(day)
        let lon = longitude(todaySunset)
        let sign = Int(lon / 30) % 12
        let guess = todaySunset.addingTimeInterval(-(lon - Double(sign) * 30) / 0.9856 * 86_400)
        let sankranti = time(of: Double(sign) * 30, near: guess)

        var firstDay = CalendarDay(containing: sankranti, in: tz)
        if sankranti > sunset(firstDay) {
            firstDay = firstDay.adding(days: 1)
        }
        let dayOfMonth = firstDay.days(to: day) + 1

        // The Tamil year turns over on Chithirai 1, in mid-April.
        let cycleStartYear = (day.month < 4 || (day.month == 4 && sign == 11)) ? day.year - 1 : day.year
        let yearIndex = ((cycleStartYear - 1987) % 60 + 60) % 60

        return TamilDate(monthIndex: sign, day: dayOfMonth, yearIndex: yearIndex, monthStart: sankranti)
    }
}
