import AppKit
import EventKit
import RasiCore

/// Fetches reminders, calendar events and weather for the days the pad is showing, but only
/// the sources that some block on the current layout actually prints. Read-only throughout.
@MainActor
final class PersonalDataService {
    private let store: StateStore
    private let model: PadModel
    private let events = EKEventStore()
    private var weatherCache: (location: GeoLocation, fetched: Date, days: [CalendarDay: PrintedWeather])?
    private var refreshTimer: Timer?

    init(store: StateStore, model: PadModel) {
        self.store = store
        self.model = model
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: events, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        // Weather changes slowly; events can be edited elsewhere at any time.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    /// Which personal sources the current layout prints.
    private var needs: (reminders: Bool, events: Bool, weather: Bool) {
        let types = Set(model.layout.rows.flatMap { $0.blocks.map(\.type) })
        return (types.contains(RemindersBlock.type), types.contains(EventsBlock.type), types.contains(WeatherBlock.type))
    }

    // MARK: - Permissions

    enum Access { case granted, denied, notAsked }

    func access(for type: EKEntityType) -> Access {
        switch EKEventStore.authorizationStatus(for: type) {
        case .fullAccess, .authorized: .granted
        case .notDetermined: .notAsked
        default: .denied
        }
    }

    func requestAccess(for type: EKEntityType) async -> Bool {
        NSApp.activate()
        do {
            return type == .reminder
                ? try await events.requestFullAccessToReminders()
                : try await events.requestFullAccessToEvents()
        } catch {
            NSLog("TamilCalendar: \(type == .reminder ? "Reminders" : "Calendar") access failed: \(error)")
            return false
        }
    }

    /// The user's event calendars, for choosing which to print.
    func eventCalendars() -> [EKCalendar] {
        guard access(for: .event) == .granted else { return [] }
        return events.calendars(for: .event).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    // MARK: - Fetching

    /// Refreshes extras for the top sheet and the one under it (it shows through).
    func refresh() {
        let day = model.context.day
        Task { await refresh(days: [day, day.adding(days: 1)]) }
    }

    private func refresh(days: [CalendarDay]) async {
        let need = needs
        // Ask for permission the first time a layout needs it.
        if need.reminders && access(for: .reminder) == .notAsked { _ = await requestAccess(for: .reminder) }
        if need.events && access(for: .event) == .notAsked { _ = await requestAccess(for: .event) }
        let forecast = need.weather ? await weather() : [:]

        for day in days {
            var extras = DayExtras()
            if need.reminders && access(for: .reminder) == .granted { extras.reminders = await reminders(on: day) }
            if need.events && access(for: .event) == .granted { extras.events = eventsOn(day) }
            extras.weather = forecast[day]
            model.extras[day] = extras
        }
    }

    private func dayBounds(_ day: CalendarDay) -> (Date, Date) {
        let start = day.date(hour: 0, in: .current)
        return (start, day.adding(days: 1).date(hour: 0, in: .current))
    }

    private func reminders(on day: CalendarDay) async -> [String] {
        // EventKit's range excludes its start and includes its end, and a reminder with no time is
        // due at exactly midnight. Shift back a second so this day's midnight is in and the next
        // day's is out.
        let (start, end) = dayBounds(day)
        let predicate = events.predicateForIncompleteReminders(
            withDueDateStarting: start.addingTimeInterval(-1), ending: end.addingTimeInterval(-1), calendars: nil)
        return await withCheckedContinuation { continuation in
            // EventKit calls back on its own queue, so nothing in this closure may be main-actor
            // isolated — including the filter and sort closures, hence the nonisolated helper.
            events.fetchReminders(matching: predicate) { @Sendable found in
                continuation.resume(returning: Self.titles(of: found, on: day))
            }
        }
    }

    /// Titles of the reminders due on `day`, earliest first. Runs on EventKit's queue.
    nonisolated private static func titles(of found: [EKReminder]?, on day: CalendarDay) -> [String] {
        // Belt and braces: keep only reminders whose due day is this day.
        let onDay = (found ?? []).filter { r in
            guard let c = r.dueDateComponents else { return false }
            return c.year == day.year && c.month == day.month && c.day == day.day
        }
        let sorted = onDay.sorted {
            ($0.dueDateComponents?.date ?? .distantFuture) < ($1.dueDateComponents?.date ?? .distantFuture)
        }
        return sorted.compactMap { $0.title?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private func eventsOn(_ day: CalendarDay) -> [PrintedEvent] {
        let (start, end) = dayBounds(day)
        let chosen = store.state.eventCalendarIDs
        let calendars = events.calendars(for: .event).filter { chosen == nil || chosen!.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else { return [] }
        let found = events.events(matching: events.predicateForEvents(withStart: start, end: end, calendars: calendars))
        let sorted = found.sorted { a, b in
            if a.isAllDay != b.isAllDay { return a.isAllDay }
            return a.startDate < b.startDate
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return sorted.map { e in
            var time: String?
            if !e.isAllDay {
                let c = cal.dateComponents([.hour, .minute], from: max(e.startDate, start))
                let h = (c.hour! + 11) % 12 + 1
                time = c.minute! == 0 ? "\(h)" : String(format: "%d.%02d", h, c.minute!)
            }
            return PrintedEvent(time: time, title: e.title ?? "")
        }
    }

    /// 16-day forecast plus current conditions from Open-Meteo (free, no account). Only the city's
    /// rounded coordinates are sent. Cached for 25 minutes per location, so each half-hourly
    /// refresh brings a new current temperature (Open-Meteo updates it every 15 minutes).
    private func weather() async -> [CalendarDay: PrintedWeather] {
        let location = model.context.location
        if let cache = weatherCache, cache.location == location, Date().timeIntervalSince(cache.fetched) < 25 * 60 {
            return cache.days
        }
        var url = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        url.queryItems = [
            .init(name: "latitude", value: String(format: "%.2f", location.latitude)),
            .init(name: "longitude", value: String(format: "%.2f", location.longitude)),
            .init(name: "current", value: "temperature_2m,weather_code,relative_humidity_2m"),
            .init(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,relative_humidity_2m_mean"),
            .init(name: "timezone", value: location.timeZoneID),
            .init(name: "forecast_days", value: "16"),
        ]
        struct Response: Decodable {
            struct Daily: Decodable {
                var time: [String]
                var weather_code: [Int?]
                var temperature_2m_max: [Double?]
                var temperature_2m_min: [Double?]
                var precipitation_probability_max: [Int?]
                var relative_humidity_2m_mean: [Double?]?
            }
            struct Current: Decodable {
                var temperature_2m: Double?
                var weather_code: Int?
                var relative_humidity_2m: Double?
            }
            var daily: Daily
            var current: Current?
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url.url!)
            let response = try JSONDecoder().decode(Response.self, from: data)
            let d = response.daily
            var days: [CalendarDay: PrintedWeather] = [:]
            for (i, iso) in d.time.enumerated() {
                let parts = iso.split(separator: "-").compactMap { Int($0) }
                guard parts.count == 3, let code = d.weather_code[i], let hi = d.temperature_2m_max[i],
                      let lo = d.temperature_2m_min[i] else { continue }
                days[CalendarDay(year: parts[0], month: parts[1], day: parts[2])] =
                    PrintedWeather(code: code, high: hi, low: lo, rain: d.precipitation_probability_max[i],
                                    humidity: d.relative_humidity_2m_mean?[i].map { Int($0.rounded()) })
            }
            if let tz = TimeZone(identifier: location.timeZoneID) {
                let today = CalendarDay(containing: Date(), in: tz)
                days[today]?.now = response.current?.temperature_2m
                days[today]?.nowCode = response.current?.weather_code
                if let h = response.current?.relative_humidity_2m { days[today]?.humidity = Int(h.rounded()) }
            }
            weatherCache = (location, Date(), days)
            return days
        } catch {
            NSLog("TamilCalendar: weather fetch failed: \(error)")
            return weatherCache?.days ?? [:]
        }
    }
}
