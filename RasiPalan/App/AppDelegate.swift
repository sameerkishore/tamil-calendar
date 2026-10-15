import AppKit
import RasiCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = StateStore()
    private var controller: AppController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if let path = UserDefaults.standard.string(forKey: "snapshot") {
            Snapshot.renderPad(state: store.state, to: URL(fileURLWithPath: path))
            exit(0)
        }
        #endif

        let controller = AppController(store: store)
        self.controller = controller
        controller.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.save()
    }
}
