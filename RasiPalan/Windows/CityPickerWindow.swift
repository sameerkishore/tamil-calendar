import AppKit
import RasiCore
import SwiftUI

/// "Choose City…": search by name and pick a result. Used when location access is off,
/// or to follow a hometown calendar while living elsewhere.
@MainActor
final class CityPickerWindowController {
    private let window: NSWindow

    init(search: @escaping (String) async -> [GeoLocation], choose: @escaping (GeoLocation) -> Void) {
        window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 380, height: 320),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Choose City"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: CityPickerView(search: search, choose: choose))
    }

    func show() {
        window.center()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func close() { window.close() }
}

private struct CityPickerView: View {
    let search: (String) async -> [GeoLocation]
    let choose: (GeoLocation) -> Void

    @State private var query = ""
    @State private var results: [GeoLocation] = []
    @State private var searching = false
    @State private var searched = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("City, e.g. Madurai", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(run)
                Button("Search", action: run)
                    .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || searching)
            }

            if searching {
                ProgressView().frame(maxWidth: .infinity)
            } else if searched && results.isEmpty {
                Text("No matches. Try adding the country, e.g. \"Ipoh, Malaysia\".")
                    .foregroundStyle(.secondary)
            }

            List(results, id: \.self) { place in
                Button { choose(place) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.name).font(.body)
                        Text(String(format: "%.2f°, %.2f° · %@", place.latitude, place.longitude, place.timeZoneID))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.bordered)

            Text("Searching uses Apple Maps; your choice is saved only on this Mac.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private func run() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        searching = true
        Task {
            results = await search(q)
            searching = false
            searched = true
        }
    }
}
