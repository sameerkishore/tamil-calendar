import Foundation

/// Compact solar astronomy after Jean Meeus, *Astronomical Algorithms* (2nd ed.), ch. 25,
/// plus the NOAA sunrise/sunset method. Solar longitude is good to about 0.01°, which puts
/// sankranti (month-start) times within about 15 minutes and sunrise/sunset within about a minute.
public enum Astronomy {
    /// ΔT (TT − UT) for the 2020s, in seconds. Good enough for solar work this decade.
    static let deltaT: Double = 69

    public static func julianDay(_ date: Date) -> Double {
        date.timeIntervalSince1970 / 86_400 + 2_440_587.5
    }

    public static func date(julianDay jd: Double) -> Date {
        Date(timeIntervalSince1970: (jd - 2_440_587.5) * 86_400)
    }

    /// Julian centuries of Terrestrial Time since J2000.0.
    static func centuries(_ date: Date) -> Double {
        (julianDay(date) + deltaT / 86_400 - 2_451_545.0) / 36_525
    }

    struct SolarPosition {
        /// Apparent geocentric (tropical) longitude, degrees 0..<360.
        var longitude: Double
        /// Declination, degrees.
        var declination: Double
        /// Equation of time, minutes (apparent − mean solar time).
        var equationOfTime: Double
    }

    static func sun(at date: Date) -> SolarPosition {
        let t = centuries(date)
        let l0 = normalize(280.46646 + 36_000.76983 * t + 0.0003032 * t * t)
        let m = 357.52911 + 35_999.05029 * t - 0.0001537 * t * t
        let e = 0.016708634 - 0.000042037 * t - 0.0000001267 * t * t
        let c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * sin(rad(m))
            + (0.019993 - 0.000101 * t) * sin(rad(2 * m))
            + 0.000289 * sin(rad(3 * m))
        let omega = 125.04 - 1934.136 * t
        let lambda = l0 + c - 0.00569 - 0.00478 * sin(rad(omega))

        let eps0 = 23.0 + (26.0 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
        let eps = eps0 + 0.00256 * cos(rad(omega))
        let declination = deg(asin(sin(rad(eps)) * sin(rad(lambda))))

        let y = pow(tan(rad(eps / 2)), 2)
        let eot = y * sin(2 * rad(l0)) - 2 * e * sin(rad(m))
            + 4 * e * y * sin(rad(m)) * cos(2 * rad(l0))
            - 0.5 * y * y * sin(4 * rad(l0)) - 1.25 * e * e * sin(2 * rad(m))

        return SolarPosition(longitude: normalize(lambda), declination: declination,
                             equationOfTime: 4 * deg(eot))
    }

    /// Lahiri (Chitrapaksha) ayanamsa in degrees, the standard for Tamil panchangams.
    public static func lahiriAyanamsa(at date: Date) -> Double {
        let t = centuries(date)
        // 23°51'25.5" at J2000 plus general precession of 5028.8"/century.
        return 23.857092 + (5028.796195 * t + 1.1054348 * t * t) / 3600
    }

    /// Sidereal (nirayana) longitude of the Sun, degrees 0..<360.
    public static func siderealSunLongitude(at date: Date) -> Double {
        normalize(sun(at: date).longitude - lahiriAyanamsa(at: date))
    }

    /// The moment the Sun's sidereal longitude equals `target` degrees, searched near `guess`.
    public static func timeOfSiderealSunLongitude(_ target: Double, near guess: Date) -> Date {
        var t = guess
        // Newton iteration; the Sun moves ~0.9856°/day so this converges in a few steps.
        for _ in 0..<8 {
            let diff = signedDifference(target, siderealSunLongitude(at: t))
            if abs(diff) < 1e-6 { break }
            t = t.addingTimeInterval(diff / 0.9856 * 86_400)
        }
        return t
    }

    public enum SunEvent { case rise, set }

    /// Sunrise or sunset on the local `day` at `location`, using the standard -0.833° altitude
    /// (upper limb on the horizon, with refraction). Returns nil during polar day/night.
    public static func sunEvent(_ event: SunEvent, on day: CalendarDay, at location: GeoLocation) -> Date? {
        let tz = location.timeZone
        var estimate = day.date(hour: event == .rise ? 6 : 18, in: tz)
        // Two refinement passes using the Sun's position at the previous estimate.
        for _ in 0..<3 {
            let sun = sun(at: estimate)
            let lat = rad(location.latitude), dec = rad(sun.declination)
            let cosH = (sin(rad(-0.833)) - sin(lat) * sin(dec)) / (cos(lat) * cos(dec))
            guard abs(cosH) <= 1 else { return nil }
            let h = deg(acos(cosH))
            // Solar noon is 12:00 local *mean solar* time on the same calendar date, i.e.
            // minutes after 00:00 UTC of that date, shifted by longitude and equation of time.
            let noonUTC = 720 - 4 * location.longitude - sun.equationOfTime
            let minutes = event == .rise ? noonUTC - 4 * h : noonUTC + 4 * h
            estimate = day.date(hour: 0, in: TimeZone(identifier: "UTC")!).addingTimeInterval(minutes * 60)
        }
        return estimate
    }

    // MARK: - Helpers

    static func rad(_ d: Double) -> Double { d * .pi / 180 }
    static func deg(_ r: Double) -> Double { r * 180 / .pi }

    static func normalize(_ d: Double) -> Double {
        let r = d.truncatingRemainder(dividingBy: 360)
        return r < 0 ? r + 360 : r
    }

    /// `a − b` wrapped into (-180, 180].
    static func signedDifference(_ a: Double, _ b: Double) -> Double {
        var d = normalize(a - b)
        if d > 180 { d -= 360 }
        return d
    }
}
