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
    var language: CardLanguage
    /// Size of the pad, 0.5…2.5.
    var padScale: CGFloat
    /// Last size used on each display, so moving the pad between screens restores its size there.
    var padScalesByDisplay: [String: CGFloat]
    /// Torn sheets lying around the desktop.
    var floatingSheets: [FloatingSheetRecord] = []
    /// Crumpled sheets lying around the desktop.
    var paperBalls: [PaperBallRecord] = []
    /// Where the waste-paper bin stands (centre, screen coordinates) and how many balls are in it.
    var binCenter: CGPoint?
    var binCount = 0
    /// Which template the sheets are printed with (CardLayout id).
    var layoutID = "classic"
    var board: BoardStyle = .none
    /// The user's own board picture, copied into Application Support.
    var boardImagePath: String?
    var boardCrop = PhotoCrop()
    /// Faint halftone, grain and warm fade on the board picture.
    var boardPhotoPrinted = true
    /// System-wide shortcut that brings the calendar in front / sends it back.
    var frontShortcut: FrontShortcut = .controlH
    /// The user's own layout from the editor (layoutID "custom").
    var customLayout: CardLayout?
    /// The user's rasi (0 = Mesham) for the horoscope block.
    var myRasi: Int?
    var signNames: SignNames = .tamil
    /// Overrides the template's paper: light, dark, or following the system appearance.
    var paperChoice: PaperChoice = .template
    /// Calendars whose events are printed; nil means all of them.
    var eventCalendarIDs: [String]?
    var soundEnabled = true
    var physics = TearPhysics()

    static func fresh() -> AppState {
        AppState(padDay: .today(), padOrigin: nil, keepOnTop: false,
                 location: nil, locationSource: .automatic, style: .traditional,
                 language: .tamilEnglish, padScale: 1, padScalesByDisplay: [:])
    }

    init(padDay: CalendarDay, padOrigin: CGPoint?, keepOnTop: Bool,
         location: GeoLocation?, locationSource: LocationSource, style: PanchangamStyle,
         language: CardLanguage, padScale: CGFloat, padScalesByDisplay: [String: CGFloat]) {
        self.padDay = padDay
        self.padOrigin = padOrigin
        self.keepOnTop = keepOnTop
        self.location = location
        self.locationSource = locationSource
        self.style = style
        self.language = language
        self.padScale = padScale
        self.padScalesByDisplay = padScalesByDisplay
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
        language = (try? c.decodeIfPresent(CardLanguage.self, forKey: .language)) ?? defaults.language
        padScale = try c.decodeIfPresent(CGFloat.self, forKey: .padScale) ?? defaults.padScale
        padScalesByDisplay = try c.decodeIfPresent([String: CGFloat].self, forKey: .padScalesByDisplay) ?? [:]
        floatingSheets = (try? c.decodeIfPresent([FloatingSheetRecord].self, forKey: .floatingSheets)) ?? []
        paperBalls = (try? c.decodeIfPresent([PaperBallRecord].self, forKey: .paperBalls)) ?? []
        binCenter = try c.decodeIfPresent(CGPoint.self, forKey: .binCenter)
        binCount = try c.decodeIfPresent(Int.self, forKey: .binCount) ?? 0
        layoutID = try c.decodeIfPresent(String.self, forKey: .layoutID) ?? "classic"
        board = (try? c.decodeIfPresent(BoardStyle.self, forKey: .board)) ?? BoardStyle.none
        boardImagePath = try c.decodeIfPresent(String.self, forKey: .boardImagePath)
        boardCrop = (try? c.decodeIfPresent(PhotoCrop.self, forKey: .boardCrop)) ?? PhotoCrop()
        boardPhotoPrinted = (try? c.decodeIfPresent(Bool.self, forKey: .boardPhotoPrinted)) ?? true
        frontShortcut = (try? c.decodeIfPresent(FrontShortcut.self, forKey: .frontShortcut)) ?? .controlH
        customLayout = try? c.decodeIfPresent(CardLayout.self, forKey: .customLayout)
        myRasi = try c.decodeIfPresent(Int.self, forKey: .myRasi)
        signNames = (try? c.decodeIfPresent(SignNames.self, forKey: .signNames)) ?? .tamil
        paperChoice = (try? c.decodeIfPresent(PaperChoice.self, forKey: .paperChoice)) ?? .template
        eventCalendarIDs = try c.decodeIfPresent([String].self, forKey: .eventCalendarIDs)
        soundEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? true
        physics = (try? c.decodeIfPresent(TearPhysics.self, forKey: .physics)) ?? TearPhysics()
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
