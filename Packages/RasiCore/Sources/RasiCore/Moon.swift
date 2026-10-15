import Foundation

extension Astronomy {
    /// Apparent geocentric (tropical) longitude of the Moon in degrees, from the largest terms
    /// of Meeus ch. 47. Good to about 0.05°, i.e. tithi and nakshatra changes within ~10 minutes.
    public static func moonLongitude(at date: Date) -> Double {
        let t = centuries(date)
        let lp = 218.3164477 + 481_267.88123421 * t
        let d = rad(297.8501921 + 445_267.1114034 * t)
        let m = rad(357.5291092 + 35_999.0502909 * t)
        let mp = rad(134.9633964 + 477_198.8675055 * t)
        let f = rad(93.2720950 + 483_202.0175233 * t)
        let e = 1 - 0.002516 * t
        let terms: [(Double, Double)] = [
            (6_288_774, sin(mp)), (1_274_027, sin(2 * d - mp)), (658_314, sin(2 * d)),
            (213_618, sin(2 * mp)), (-185_116 * e, sin(m)), (-114_332, sin(2 * f)),
            (58_793, sin(2 * d - 2 * mp)), (57_066 * e, sin(2 * d - m - mp)), (53_322, sin(2 * d + mp)),
            (45_758 * e, sin(2 * d - m)), (-40_923 * e, sin(m - mp)), (-34_720, sin(d)),
            (-30_383 * e, sin(m + mp)), (15_327, sin(2 * d - 2 * f)), (-12_528, sin(mp + 2 * f)),
            (10_980, sin(mp - 2 * f)), (10_675, sin(4 * d - mp)), (10_034, sin(3 * mp)),
            (8_548, sin(4 * d - 2 * mp)), (-7_888 * e, sin(2 * d + m - mp)), (-6_766 * e, sin(2 * d + m)),
            (-5_163, sin(d - mp)),
        ]
        let sum = terms.reduce(0) { $0 + $1.0 * $1.1 }
        return normalize(lp + sum / 1_000_000)
    }

    public static func siderealMoonLongitude(at date: Date) -> Double {
        normalize(moonLongitude(at: date) - lahiriAyanamsa(at: date))
    }

    /// Moon − Sun elongation, 0…360. Each 12° is one tithi.
    public static func elongation(at date: Date) -> Double {
        normalize(moonLongitude(at: date) - sun(at: date).longitude)
    }

    /// The first moment after `start` when `value` reaches `target` (degrees, wrapping),
    /// given it increases at about `rate` degrees a day.
    static func timeWhen(_ value: (Date) -> Double, reaches target: Double, after start: Date, rate: Double) -> Date {
        var t = start.addingTimeInterval(normalize(target - value(start)) / rate * 86_400)
        for _ in 0..<8 {
            let diff = signedDifference(target, value(t))
            if abs(diff) < 1e-5 { break }
            t = t.addingTimeInterval(diff / rate * 86_400)
        }
        return t
    }
}
