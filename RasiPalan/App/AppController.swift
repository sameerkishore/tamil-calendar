import AppKit
import Observation
import RasiCore

/// What the pad is currently showing. Views observe this; only `AppController` writes it.
@MainActor
@Observable
final class PadModel {
    var context: DayContext
    /// Tomorrow's sheet, faintly visible through the paper.
    var nextContext: DayContext
    var layout: CardLayout
    var language: CardLanguage
    var scale: CGFloat
    /// The top sheet is off being torn; the pad shows the next day on top.
    var isTearing = false

    init(context: DayContext, layout: CardLayout = .classic, language: CardLanguage = .tamilEnglish, scale: CGFloat = 1) {
        self.context = context
        nextContext = context.next()
        self.layout = layout
        self.language = language
        self.scale = scale
    }
}

extension DayContext {
    func next() -> DayContext {
        DayContext(day: day.adding(days: 1), location: location, style: style)
    }
}

/// Owns the app's state and services, and recomputes the sheet whenever any input changes
/// (pad date, location, panchangam style).
@MainActor
final class AppController {
    let store: StateStore
    let model: PadModel
    private let locationService = LocationService()
    private var pad: PadWindowController?
    private var menuBar: MenuBarController?
    private var cityPicker: CityPickerWindowController?
    private let tear = TearController()
    private var floatingSheets: FloatingSheetsController?

    /// Only move the saved location if the user has really travelled.
    private static let relocationThresholdKm = 25.0

    init(store: StateStore) {
        self.store = store
        if store.state.location == nil {
            // Something sensible to show while Core Location answers (or if it never does).
            store.state.location = .fallback(for: .current)
            store.state.locationSource = .timeZone
            store.save()
        }
        model = PadModel(context: Self.context(for: store.state), language: store.state.language,
                         scale: store.state.padScale)
    }

    func start() {
        SoundPlayer.shared.isEnabled = state.soundEnabled
        let pad = PadWindowController(store: store, model: model)
        self.pad = pad
        menuBar = MenuBarController(app: self, pad: pad)
        pad.show()

        let sheets = FloatingSheetsController(store: store, model: model)
        sheets.onClick = { _ in SoundPlayer.shared.play("rustle", volume: 0.6) } // crumpling arrives in milestone 5
        sheets.restore(level: pad.level)
        floatingSheets = sheets

        pad.onTearBegan = { [weak self] point in
            guard let self else { return }
            tear.begin(at: point, sheetRect: pad.sheetScreenRect, context: model.context, layout: model.layout,
                       theme: CardTheme(scale: model.scale, language: model.language), level: pad.level)
        }
        pad.onTearMoved = { [weak self] point, time in self?.tear.move(to: point, time: time) }
        pad.onTearEnded = { [weak self] point, time in self?.tear.end(at: point, time: time) }
        tear.onLift = { [weak self] in self?.model.isTearing = true }
        tear.onSettle = { [weak self] in self?.model.isTearing = false }
        tear.onTornOff = { [weak self] in self?.advancePad() }
        tear.onDrop = { [weak self] sheet in
            guard let self, let pad = self.pad else { return }
            floatingSheets?.add(sheet, level: pad.level)
        }
        updateAutomaticLocation()

        NotificationCenter.default.addObserver(forName: .NSSystemTimeZoneDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.timeZoneChanged() }
        }
    }

    var state: AppState { store.state }

    private static func context(for state: AppState) -> DayContext {
        DayContext(day: state.padDay, location: state.location ?? .fallback(for: .current), style: state.style)
    }

    private func commit() {
        store.save()
        model.context = Self.context(for: store.state)
        model.nextContext = model.context.next()
        model.language = store.state.language
    }

    // MARK: - Location

    func useAutomaticLocation() {
        store.state.locationSource = .timeZone   // anything but .manual, so the next fix is accepted
        commit()
        updateAutomaticLocation(force: true)
    }

    func setManualLocation(_ location: GeoLocation) {
        store.state.location = location
        store.state.locationSource = .manual
        commit()
    }

    func chooseCity() {
        if cityPicker == nil {
            cityPicker = CityPickerWindowController(
                search: { [locationService] query in await locationService.search(query) },
                choose: { [weak self] location in
                    self?.setManualLocation(location)
                    self?.cityPicker?.close()
                })
        }
        cityPicker?.show()
    }

    private func updateAutomaticLocation(force: Bool = false) {
        guard state.locationSource != .manual else { return }
        locationService.requestLocation { [weak self] found in
            guard let self, self.state.locationSource != .manual else { return }
            if let found {
                let moved = self.state.location.map { $0.distance(to: found) > Self.relocationThresholdKm } ?? true
                if force || moved || self.state.locationSource != .automatic {
                    self.store.state.location = found
                    self.store.state.locationSource = .automatic
                    self.commit()
                }
            } else if self.state.locationSource == .timeZone {
                self.store.state.location = .fallback(for: .current)
                self.commit()
            }
        }
    }

    private func timeZoneChanged() {
        if state.locationSource == .timeZone {
            store.state.location = .fallback(for: .current)
            commit()
        }
        updateAutomaticLocation()
    }

    // MARK: - Settings

    func setLanguage(_ language: CardLanguage) {
        store.state.language = language
        commit()
    }

    func setStyle(_ style: PanchangamStyle) {
        store.state.style = style
        commit()
    }

    /// A sheet came off: the pad moves on to the next day.
    private func advancePad() {
        store.state.padDay = store.state.padDay.adding(days: 1)
        model.isTearing = false
        commit()
    }

    func setKeepOnTop(_ on: Bool) {
        store.state.keepOnTop = on
        store.save()
        pad?.applyLevel()
        if let pad { floatingSheets?.setLevel(pad.level) }
    }

    func setSoundEnabled(_ on: Bool) {
        store.state.soundEnabled = on
        store.save()
        SoundPlayer.shared.isEnabled = on
    }

    /// Debug: browse dates without tearing.
    func shiftPadDay(by days: Int) {
        store.state.padDay = store.state.padDay.adding(days: days)
        commit()
    }

    func resetPadDayToToday() {
        store.state.padDay = .today()
        commit()
    }
}
