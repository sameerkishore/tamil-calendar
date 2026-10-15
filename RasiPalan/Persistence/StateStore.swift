import Foundation
import RasiCore

/// Where the saved location came from.
enum LocationSource: String, Codable {
    /// Core Location, refreshed at launch.
    case automatic
    /// Picked by the user with "Choose City…".
    case manual
    /// The time zone's main city, used until a real location is known.
    case timeZone
}

/// Everything the app remembers between launches.
struct AppState: Codable {
    /// The date on the top sheet of the pad. Only tearing moves it forward.
    var padDay: CalendarDay
    /// Bottom-left of the pad window in screen coordinates; nil means "use the default spot".
    var padOrigin: CGPoint?
    /// Raise the pad above normal windows instead of sitting on the desktop.
    var keepOnTop: Bool
    var location: GeoLocation?
    var locationSource: LocationSource
    var style: PanchangamStyle

    static func fresh() -> AppState {
        AppState(padDay: .today(), padOrigin: nil, keepOnTop: false,
                 location: nil, locationSource: .automatic, style: .traditional)
    }

    init(padDay: CalendarDay, padOrigin: CGPoint?, keepOnTop: Bool,
         location: GeoLocation?, locationSource: LocationSource, style: PanchangamStyle) {
        self.padDay = padDay
        self.padOrigin = padOrigin
        self.keepOnTop = keepOnTop
        self.location = location
        self.locationSource = locationSource
        self.style = style
    }

    // Tolerant decoding: keys added in later versions fall back to defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppState.fresh()
        padDay = try c.decodeIfPresent(CalendarDay.self, forKey: .padDay) ?? defaults.padDay
        padOrigin = try c.decodeIfPresent(CGPoint.self, forKey: .padOrigin)
        keepOnTop = try c.decodeIfPresent(Bool.self, forKey: .keepOnTop) ?? defaults.keepOnTop
        location = try c.decodeIfPresent(GeoLocation.self, forKey: .location)
        locationSource = (try? c.decodeIfPresent(LocationSource.self, forKey: .locationSource)) ?? defaults.locationSource
        style = (try? c.decodeIfPresent(PanchangamStyle.self, forKey: .style)) ?? defaults.style
    }
}

/// Loads and saves `AppState` as JSON in ~/Library/Application Support/RasiPalan/state.json.
@MainActor
final class StateStore {
    var state: AppState
    private let url: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RasiPalan", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("state.json")

        if let data = try? Data(contentsOf: url),
           let saved = try? JSONDecoder().decode(AppState.self, from: data) {
            state = saved
        } else {
            // First launch: the pad starts on the installer's own today.
            state = .fresh()
            save()
        }
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try encoder.encode(state).write(to: url, options: .atomic)
        } catch {
            NSLog("RasiPalan: failed to save state: \(error)")
        }
    }
}
