import Foundation

/// Where the calendar is being read. Everything location-dependent (sunrise, timings,
/// even which civil day a month starts on) is computed for this place.
public struct GeoLocation: Codable, Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public var timeZoneID: String
    /// City name to print on the card, e.g. "Chennai".
    public var name: String

    public init(latitude: Double, longitude: Double, timeZoneID: String, name: String) {
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneID = timeZoneID
        self.name = name
    }

    public var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }

    public static let chennai = GeoLocation(latitude: 13.0827, longitude: 80.2707,
                                            timeZoneID: "Asia/Kolkata", name: "Chennai")

    /// Great-circle distance in kilometres.
    public func distance(to other: GeoLocation) -> Double {
        let r = 6371.0
        let p1 = latitude * .pi / 180, p2 = other.latitude * .pi / 180
        let dp = p2 - p1, dl = (other.longitude - longitude) * .pi / 180
        let a = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2)
        return 2 * r * asin(min(1, sqrt(a)))
    }

    /// Offline fallback: the representative city of a time zone, from the system's tz database
    /// (`/usr/share/zoneinfo/zone.tab`). India's zone maps to Chennai rather than Kolkata,
    /// since this is a Tamil calendar.
    public static func fallback(for timeZone: TimeZone, zoneTab: String? = nil) -> GeoLocation {
        if timeZone.identifier == "Asia/Kolkata" || timeZone.identifier == "Asia/Calcutta" {
            return .chennai
        }
        let table = zoneTab ?? (try? String(contentsOfFile: "/usr/share/zoneinfo/zone.tab", encoding: .utf8)) ?? ""
        for line in table.split(separator: "\n") where !line.hasPrefix("#") {
            let cols = line.split(separator: "\t")
            guard cols.count >= 3, cols[2] == timeZone.identifier,
                  let (lat, lon) = parseISO6709(String(cols[1])) else { continue }
            let city = cols[2].split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") }
            return GeoLocation(latitude: lat, longitude: lon, timeZoneID: timeZone.identifier,
                               name: city ?? timeZone.identifier)
        }
        return .chennai
    }

    /// Parses zone.tab coordinates like "+1305+08017" or "+340308-1181434".
    static func parseISO6709(_ s: String) -> (Double, Double)? {
        guard let split = s.dropFirst().firstIndex(where: { $0 == "+" || $0 == "-" }) else { return nil }
        func parse(_ part: Substring, degreeDigits: Int) -> Double? {
            let sign: Double = part.first == "-" ? -1 : 1
            let digits = Array(part.dropFirst())
            guard digits.count >= degreeDigits + 2, digits.allSatisfy(\.isNumber) else { return nil }
            let d = Double(String(digits[0..<degreeDigits]))!
            let m = Double(String(digits[degreeDigits..<degreeDigits + 2]))!
            let sec = digits.count >= degreeDigits + 4 ? Double(String(digits[degreeDigits + 2..<degreeDigits + 4]))! : 0
            return sign * (d + m / 60 + sec / 3600)
        }
        guard let lat = parse(s[s.startIndex..<split], degreeDigits: 2),
              let lon = parse(s[split...], degreeDigits: 3) else { return nil }
        return (lat, lon)
    }
}
