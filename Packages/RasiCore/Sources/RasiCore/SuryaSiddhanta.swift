import Foundation

/// The traditional (Vakyam-style) solar theory used by Tamil Nadu wall calendars:
/// Surya Siddhanta mean motions and the classical sine table, following the "modern Hindu"
/// algorithms in Reingold & Dershowitz, *Calendrical Calculations* (ch. 20).
///
/// It deliberately reproduces the old arithmetic, not the true sky: its sankrantis can land
/// hours away from the modern (Thirukanitha) ones, which is exactly why printed Tamil calendars
/// sometimes start a month a day later than astronomy sites.
public enum SuryaSiddhanta {
    // Constants from Calendrical Calculations.
    static let siderealYear = 365.0 + 279_457.0 / 1_080_000.0
    static let anomalisticYear = 1_577_917_828_000.0 / (4_320_000_000.0 - 387.0)
    /// Kali Yuga epoch, 18 Feb 3102 BCE (Julian), as a Julian Day at local midnight in Ujjain.
    static let epochJD = 588_465.5
    static let creationJD = epochJD - 1_955_880_000.0 * siderealYear
    /// Ujjain, the prime meridian of Indian astronomy (75°46'6" E).
    static let ujjainLongitude = 75.0 + 46.0 / 60 + 6.0 / 3600

    /// Sidereal solar longitude in degrees, per the Surya Siddhanta.
    public static func solarLongitude(at date: Date) -> Double {
        // Hindu astronomy counts days from midnight in Ujjain local mean time.
        let jd = Astronomy.julianDay(date) + ujjainLongitude / 360
        return truePosition(jd: jd, period: siderealYear, size: 14.0 / 360,
                            anomalistic: anomalisticYear, change: 1.0 / 42)
    }

    /// The moment the traditional Sun reaches `target` degrees, searched near `guess`.
    public static func timeOfSolarLongitude(_ target: Double, near guess: Date) -> Date {
        var t = guess
        for _ in 0..<12 {
            let diff = Astronomy.signedDifference(target, solarLongitude(at: t))
            if abs(diff) < 1e-7 { break }
            t = t.addingTimeInterval(diff / 0.9856 * 86_400)
        }
        return t
    }

    static func meanPosition(jd: Double, period: Double) -> Double {
        let x = (jd - creationJD) / period
        return 360 * (x - floor(x))
    }

    static func truePosition(jd: Double, period: Double, size: Double, anomalistic: Double, change: Double) -> Double {
        let lambda = meanPosition(jd: jd, period: period)
        let offset = sine(meanPosition(jd: jd, period: anomalistic))
        let contraction = abs(offset) * change * size
        let equation = arcsin(offset * (size - contraction))
        return Astronomy.normalize(lambda - equation)
    }

    // MARK: - The classical 24-entry sine table (R = 3438, steps of 225′)

    static let step = 225.0 / 60

    static func sineTable(_ entry: Int) -> Double {
        let exact = 3438 * sin(Astronomy.rad(Double(entry) * step))
        let error = 0.215 * sign(exact) * sign(abs(exact) - 1716)
        return (exact + error).rounded() / 3438
    }

    static func sine(_ theta: Double) -> Double {
        let entry = theta / step
        let fraction = entry - floor(entry)
        return fraction * sineTable(Int(ceil(entry))) + (1 - fraction) * sineTable(Int(floor(entry)))
    }

    static func arcsin(_ amp: Double) -> Double {
        if amp < 0 { return -arcsin(-amp) }
        var pos = 0
        while amp > sineTable(pos) { pos += 1 }
        let below = sineTable(pos - 1)
        return step * (Double(pos) - 1 + (amp - below) / (sineTable(pos) - below))
    }

    private static func sign(_ x: Double) -> Double { x > 0 ? 1 : (x < 0 ? -1 : 0) }
}
