import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = StateStore()
    private var pad: PadWindowController?
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if let path = UserDefaults.standard.string(forKey: "snapshot") {
            Snapshot.renderPad(day: store.state.padDay, to: URL(fileURLWithPath: path))
            exit(0)
        }
        #endif

        let pad = PadWindowController(store: store)
        self.pad = pad
        menuBar = MenuBarController(store: store, pad: pad)
        pad.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.save()
    }
}
