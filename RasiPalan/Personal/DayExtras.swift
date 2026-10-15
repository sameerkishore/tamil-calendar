import RasiCore
import SwiftUI

/// Things printed on a sheet that come from the user's own world rather than the almanac.
/// Stored with torn sheets, so what was printed stays printed.
struct DayExtras: Codable, Hashable {
    /// nil = not available (no permission, or the source isn't on the sheet).
    var reminders: [String]?
    var events: [PrintedEvent]?
    var weather: PrintedWeather?
}

struct PrintedEvent: Codable, Hashable {
    /// Calendar-style start time ("9.30"), or nil for all-day events.
    var time: String?
    var title: String
}

/// One day's forecast, as Open-Meteo reports it.
struct PrintedWeather: Codable, Hashable {
    /// WMO weather code.
    var code: Int
    var high: Double
    var low: Double
    /// Chance of rain, percent.
    var rain: Int?

    var description: LocalizedText {
        switch code {
        case 0: .init(ta: "தெளிவான வானம்", en: "Clear sky")
        case 1, 2: .init(ta: "ஓரளவு மேகமூட்டம்", en: "Partly cloudy")
        case 3: .init(ta: "மேகமூட்டம்", en: "Overcast")
        case 45, 48: .init(ta: "மூடுபனி", en: "Fog")
        case 51...57: .init(ta: "தூறல்", en: "Drizzle")
        case 61...67: .init(ta: "மழை", en: "Rain")
        case 71...77, 85, 86: .init(ta: "பனிப்பொழிவு", en: "Snow")
        case 80...82: .init(ta: "மழைச் சாரல்", en: "Showers")
        case 95...99: .init(ta: "இடியுடன் மழை", en: "Thunderstorms")
        default: .init(ta: "வானிலை", en: "Weather")
        }
    }

    /// SF Symbol, printed in ink like everything else.
    var symbol: String {
        switch code {
        case 0: "sun.max"
        case 1, 2: "cloud.sun"
        case 3: "cloud"
        case 45, 48: "cloud.fog"
        case 51...57: "cloud.drizzle"
        case 61...67: "cloud.rain"
        case 71...77, 85, 86: "cloud.snow"
        case 80...82: "cloud.heavyrain"
        case 95...99: "cloud.bolt.rain"
        default: "cloud"
        }
    }
}

private struct SheetExtrasKey: EnvironmentKey {
    static let defaultValue: DayExtras? = nil
}

extension EnvironmentValues {
    /// The personal data for the sheet being drawn (set by `SheetFace`).
    var sheetExtras: DayExtras? {
        get { self[SheetExtrasKey.self] }
        set { self[SheetExtrasKey.self] = newValue }
    }
}
