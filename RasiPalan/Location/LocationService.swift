import AppKit
import CoreLocation
import RasiCore

/// One-shot, city-level location lookup. Reports a `GeoLocation` with the city name and time zone,
/// or nil if permission is denied or the lookup fails (callers then use the time-zone fallback).
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var completion: ((GeoLocation?) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestLocation(_ completion: @escaping (GeoLocation?) -> Void) {
        self.completion = completion
        switch manager.authorizationStatus {
        case .notDetermined:
            // The permission prompt only shows for an active app.
            NSApp.activate()
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        default:
            finish(nil)
        }
    }

    /// Forward geocoding for "Choose City…".
    func search(_ query: String) async -> [GeoLocation] {
        let placemarks = (try? await geocoder.geocodeAddressString(query)) ?? []
        return placemarks.compactMap { Self.geoLocation(from: $0) }
    }

    private func finish(_ location: GeoLocation?) {
        completion?(location)
        completion = nil
    }

    private static func geoLocation(from placemark: CLPlacemark) -> GeoLocation? {
        guard let loc = placemark.location else { return nil }
        return geoLocation(loc, placemark: placemark)
    }

    private static func geoLocation(_ loc: CLLocation, placemark: CLPlacemark?) -> GeoLocation {
        GeoLocation(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude,
                    timeZoneID: (placemark?.timeZone ?? .current).identifier,
                    name: placemark?.locality ?? placemark?.name ?? "My location")
    }

    // MARK: - CLLocationManagerDelegate (delivered on the main thread, where the manager was made)

    nonisolated func locationManagerDidChangeAuthorization(_: CLLocationManager) {
        MainActor.assumeIsolated {
            guard completion != nil else { return }
            switch self.manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse: self.manager.requestLocation()
            case .notDetermined: break
            default: finish(nil)
            }
        }
    }

    nonisolated func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated {
            guard let location = locations.last else { return finish(nil) }
            Task {
                // The city name is a nicety; offline, the coordinates alone are enough.
                let placemark = try? await geocoder.reverseGeocodeLocation(location).first
                finish(Self.geoLocation(location, placemark: placemark))
            }
        }
    }

    nonisolated func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated { finish(nil) }
    }
}
