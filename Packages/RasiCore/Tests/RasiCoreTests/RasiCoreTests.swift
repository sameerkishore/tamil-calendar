import Foundation
import Testing
@testable import RasiCore

private let chennai = GeoLocation.chennai
private let london = GeoLocation(latitude: 51.5074, longitude: -0.1278, timeZoneID: "Europe/London", name: "London")

private func clock(_ date: Date?, _ tz: TimeZone) -> (Int, Int) {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = tz
    let c = cal.dateComponents([.hour, .minute], from: date!)
    return (c.hour!, c.minute!)
}

private func minutes(_ date: Date?, _ tz: TimeZone) -> Int {
    let (h, m) = clock(date, tz)
    return h * 60 + m
}

@Suite("Reference sheet: Rani Muthu calendar, 15 Oct 2026")
struct ReferenceSheet {
    let ctx = DayContext(day: CalendarDay(year: 2026, month: 10, day: 15), location: chennai, style: .traditional)

    @Test func tamilDate() {
        #expect(ctx.tamil.month.ta == "புரட்டாசி")
        #expect(ctx.tamil.day == 28)
        #expect(ctx.tamil.yearName.ta == "பராபவ")
    }

    @Test func weekday() {
        #expect(ctx.weekday.ta == "வியாழன்")
        #expect(ctx.gregorianMonth.ta == "அக்டோபர்")
    }

    @Test func traditionalTimings() {
        #expect(ctx.range(ctx.timings.rahuKalam) == "1.30-3")
        #expect(ctx.range(ctx.timings.kuligai) == "9-10.30")
        #expect(ctx.range(ctx.timings.yamagandam) == "6-7.30")
        #expect(ctx.timings.soolam.en == "South")
    }
}

@Suite struct TamilCalendarTests {
    /// Month starts printed by traditional Tamil Nadu calendars (nivacalendar.in, cross-checked
    /// against the Rani Muthu sheet and the 2026 Pongal holiday). Indexed Thai … Margazhi.
    static let traditionalMonthStarts: [Int: [(Int, Int)]] = [
        2025: [(1, 14), (2, 13), (3, 15), (4, 14), (5, 15), (6, 15), (7, 17), (8, 17), (9, 17), (10, 18), (11, 17), (12, 16)],
        2026: [(1, 15), (2, 13), (3, 15), (4, 14), (5, 15), (6, 15), (7, 17), (8, 18), (9, 18), (10, 18), (11, 17), (12, 16)],
        2027: [(1, 15), (2, 13), (3, 15), (4, 14), (5, 15), (6, 16), (7, 17), (8, 18), (9, 18), (10, 18), (11, 17), (12, 17)],
    ]
    static let thaiFirst = [9, 10, 11, 0, 1, 2, 3, 4, 5, 6, 7, 8]

    @Test(arguments: [2025, 2026, 2027])
    func traditionalMatchesPrintedCalendars(year: Int) {
        for (i, (m, d)) in Self.traditionalMonthStarts[year]!.enumerated() {
            let first = CalendarDay(year: year, month: m, day: d)
            let t = TamilCalendar.date(for: first, at: chennai, style: .traditional)
            #expect(t.monthIndex == Self.thaiFirst[i] && t.day == 1, "\(first): got \(t.month.en) \(t.day)")
            let eve = TamilCalendar.date(for: first.adding(days: -1), at: chennai, style: .traditional)
            #expect(eve.monthIndex == (Self.thaiFirst[i] + 11) % 12, "\(first) eve")
        }
    }

    /// Traditional dates don't depend on where the calendar hangs.
    @Test func traditionalIsReckonedForTamilNadu() {
        let day = CalendarDay(year: 2026, month: 10, day: 15)
        #expect(TamilCalendar.date(for: day, at: london, style: .traditional).day == 28)
    }

    /// Drik (Thirukanitha): Kanya sankranti 07:58 IST on 17 Sep 2026 per Drik Panchang,
    /// so Purattasi starts a day earlier than on printed calendars.
    @Test func preciseFollowsTrueSky() {
        let p = TamilCalendar.date(for: CalendarDay(year: 2026, month: 9, day: 17), at: chennai, style: .precise)
        #expect(p.month.en == "Purattasi" && p.day == 1)
        let tz = chennai.timeZone
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        let c = cal.dateComponents([.month, .day, .hour, .minute], from: p.monthStart)
        #expect(c.month == 9 && c.day == 17)
        #expect(abs(c.hour! * 60 + c.minute! - (7 * 60 + 58)) <= 10)
        #expect(TamilCalendar.date(for: CalendarDay(year: 2026, month: 10, day: 15), at: chennai, style: .precise).day == 29)
    }

    @Test(arguments: PanchangamStyle.allCases)
    func tamilNewYear2026(style: PanchangamStyle) {
        let newYear = TamilCalendar.date(for: CalendarDay(year: 2026, month: 4, day: 14), at: chennai, style: style)
        #expect(newYear.month.en == "Chithirai")
        #expect(newYear.day == 1)
        #expect(newYear.yearName.en == "Parabhava")

        let eve = TamilCalendar.date(for: CalendarDay(year: 2026, month: 4, day: 13), at: chennai, style: style)
        #expect(eve.month.en == "Panguni")
        #expect(eve.yearName.en == "Visuvaavasu")
    }

    @Test func yearCycle() {
        #expect(TamilCalendar.date(for: CalendarDay(year: 2025, month: 10, day: 15), at: chennai).yearName.en == "Visuvaavasu")
        #expect(TamilCalendar.date(for: CalendarDay(year: 1987, month: 6, day: 1), at: chennai).yearName.en == "Prabhava")
        #expect(TamilCalendar.date(for: CalendarDay(year: 2047, month: 6, day: 1), at: chennai).yearName.en == "Prabhava")
    }

    /// Walking day by day, the Tamil date must either advance by one or start a new month on day 1,
    /// and every month must be 29–32 days long.
    @Test(arguments: [(PanchangamStyle.traditional, chennai), (.precise, chennai), (.precise, london)])
    func continuityAcrossYears(style: PanchangamStyle, place: GeoLocation) {
        var day = CalendarDay(year: 2025, month: 1, day: 1)
        var previous = TamilCalendar.date(for: day, at: place, style: style)
        var monthLengths: [Int] = []
        for _ in 0..<(365 * 3) {
            day = day.adding(days: 1)
            let current = TamilCalendar.date(for: day, at: place, style: style)
            if current.monthIndex == previous.monthIndex {
                #expect(current.day == previous.day + 1, "\(day)")
            } else {
                #expect(current.monthIndex == (previous.monthIndex + 1) % 12, "\(day)")
                #expect(current.day == 1, "\(day)")
                monthLengths.append(previous.day)
            }
            previous = current
        }
        #expect(monthLengths.count >= 34)
        #expect(monthLengths.allSatisfy { (29...32).contains($0) }, "\(monthLengths)")
    }
}

@Suite struct SunTests {
    @Test func chennaiOctober() {
        let day = CalendarDay(year: 2026, month: 10, day: 15)
        let tz = chennai.timeZone
        // Published tables: sunrise ~6:00, sunset ~17:53 IST.
        #expect(abs(minutes(Astronomy.sunEvent(.rise, on: day, at: chennai), tz) - (6 * 60)) <= 4)
        #expect(abs(minutes(Astronomy.sunEvent(.set, on: day, at: chennai), tz) - (17 * 60 + 53)) <= 4)
    }

    @Test func londonMidsummer() {
        let day = CalendarDay(year: 2026, month: 6, day: 21)
        let tz = london.timeZone
        // Sunrise 04:43, sunset 21:21 BST.
        #expect(abs(minutes(Astronomy.sunEvent(.rise, on: day, at: london), tz) - (4 * 60 + 43)) <= 3)
        #expect(abs(minutes(Astronomy.sunEvent(.set, on: day, at: london), tz) - (21 * 60 + 21)) <= 3)
    }

    @Test func farEastTimeZone() {
        let auckland = GeoLocation(latitude: -36.85, longitude: 174.76, timeZoneID: "Pacific/Auckland", name: "Auckland")
        let day = CalendarDay(year: 2026, month: 12, day: 21)
        let rise = Astronomy.sunEvent(.rise, on: day, at: auckland)
        // Must fall on the requested local day (around 05:58 NZDT).
        #expect(CalendarDay(containing: rise!, in: auckland.timeZone) == day)
        #expect(abs(minutes(rise, auckland.timeZone) - (5 * 60 + 58)) <= 5)
    }

    @Test func polarNight() {
        let tromso = GeoLocation(latitude: 69.65, longitude: 18.96, timeZoneID: "Europe/Oslo", name: "Tromsø")
        #expect(Astronomy.sunEvent(.rise, on: CalendarDay(year: 2026, month: 12, day: 21), at: tromso) == nil)
        // Timings still work, falling back to the traditional 6–6 day.
        let ctx = DayContext(day: CalendarDay(year: 2026, month: 12, day: 21), location: tromso, style: .precise)
        #expect(ctx.timings.rahuKalam.end > ctx.timings.rahuKalam.start)
    }

    @Test func preciseTimingsUseSunriseToSunset() {
        let ctx = DayContext(day: CalendarDay(year: 2026, month: 10, day: 15), location: chennai, style: .precise)
        let day = ctx.sunset!.timeIntervalSince(ctx.sunrise!)
        // Thursday Rahu is the 6th eighth of the day.
        #expect(abs(ctx.timings.rahuKalam.start.timeIntervalSince(ctx.sunrise!) - day * 5 / 8) < 1)
    }
}

@Suite struct LocationTests {
    @Test func parsesZoneTabCoordinates() {
        let (lat, lon) = GeoLocation.parseISO6709("+340308-1181434")!
        #expect(abs(lat - 34.0522) < 0.001)
        #expect(abs(lon - -118.2428) < 0.001)
        let (lat2, lon2) = GeoLocation.parseISO6709("+0117+10351")!
        #expect(abs(lat2 - 1.2833) < 0.001 && abs(lon2 - 103.85) < 0.001)
    }

    @Test func fallbacks() {
        #expect(GeoLocation.fallback(for: TimeZone(identifier: "Asia/Kolkata")!) == .chennai)
        let sg = GeoLocation.fallback(for: TimeZone(identifier: "Asia/Singapore")!)
        #expect(sg.name == "Singapore")
        #expect(abs(sg.latitude - 1.28) < 0.05)
        let la = GeoLocation.fallback(for: TimeZone(identifier: "America/Los_Angeles")!)
        #expect(la.name == "Los Angeles")
    }

    @Test func distance() {
        let madurai = GeoLocation(latitude: 9.9252, longitude: 78.1198, timeZoneID: "Asia/Kolkata", name: "Madurai")
        #expect(abs(GeoLocation.chennai.distance(to: madurai) - 422) < 15)
    }
}

@Suite struct CalendarDayTests {
    @Test func arithmetic() {
        let d = CalendarDay(year: 2026, month: 12, day: 31)
        #expect(d.adding(days: 1) == CalendarDay(year: 2027, month: 1, day: 1))
        #expect(d.days(to: CalendarDay(year: 2027, month: 3, day: 1)) == 60)
        #expect(CalendarDay(year: 2026, month: 10, day: 15).weekday == 5) // Thursday
    }
}

@Suite struct RasiPalanTests {
    @Test func stableAndVaried() {
        let day = CalendarDay(year: 2026, month: 10, day: 15)
        let a = RasiPalan.words(for: day), b = RasiPalan.words(for: day)
        #expect(a == b)
        #expect(a.count == 12)
        #expect(Set(a.map(\.en)).count == 12)
        #expect(RasiPalan.words(for: day.adding(days: 1)) != a)
    }
}

@Suite struct PanchangamTests {
    @Test func referenceSheet() {
        // Rani Muthu sheet for 15 Oct 2026: Panchami (till 3.10 past midnight), Kettai all day.
        let ctx = DayContext(day: CalendarDay(year: 2026, month: 10, day: 15), location: chennai)
        print("ref:", ctx.panchangam.tithi.name.en, ctx.until(ctx.panchangam.tithi).en,
              ctx.panchangam.nakshatra.name.en, ctx.until(ctx.panchangam.nakshatra).en, ctx.observances.map(\.en))
        #expect(ctx.panchangam.tithi.name.en == "Panchami")
        #expect(ctx.panchangam.nakshatra.name.en == "Kettai")
        #expect(ctx.observances.contains { $0.en == "Abdul Kalam's birthday" })
    }

    @Test func moonMovesSensibly() {
        let a = Date(timeIntervalSince1970: 1_800_000_000)
        let d = Astronomy.signedDifference(Astronomy.moonLongitude(at: a.addingTimeInterval(86_400)), Astronomy.moonLongitude(at: a))
        #expect(d > 11 && d < 15.5)
    }
}
