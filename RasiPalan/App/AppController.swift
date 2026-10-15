import AppKit
import Observation
import RasiCore

/// What the pad is currently showing. Views observe this; only `AppController` writes it.
@MainActor
@Observable
final class PadModel {
    var context: DayContext

    init(context: DayContext) {
        self.context = context
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
        model = PadModel(context: Self.context(for: store.state))
    }

    func start() {
        let pad = PadWindowController(store: store, model: model)
        self.pad = pad
        menuBar = MenuBarController(app: self, pad: pad)
        pad.show()
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

    func setStyle(_ style: PanchangamStyle) {
        store.state.style = style
        commit()
    }

    /// Debug only: stand-in for tearing until milestone 4.
    func shiftPadDay(by days: Int) {
        store.state.padDay = store.state.padDay.adding(days: days)
        commit()
    }

    func resetPadDayToToday() {
        store.state.padDay = .today()
        commit()
    }
}
