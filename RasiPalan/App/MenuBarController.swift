import AppKit

/// The menu-bar icon and its menu. The app has no Dock icon, so this is its only chrome.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let store: StateStore
    private let pad: PadWindowController
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    private let dateItem = NSMenuItem()
    private let keepOnTopItem = NSMenuItem()

    init(store: StateStore, pad: PadWindowController) {
        self.store = store
        self.pad = pad
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Rasi Palan")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        menu.delegate = self

        dateItem.isEnabled = false
        menu.addItem(dateItem)
        menu.addItem(.separator())

        menu.addItem(item("Show Pad", #selector(showPad)))
        keepOnTopItem.title = "Keep Pad Above Windows"
        keepOnTopItem.action = #selector(toggleKeepOnTop)
        keepOnTopItem.target = self
        menu.addItem(keepOnTopItem)
        menu.addItem(item("Reset Pad Position", #selector(resetPosition)))
        menu.addItem(.separator())
        menu.addItem(item("About Rasi Palan", #selector(showAbout)))
        menu.addItem(item("Quit Rasi Palan", #selector(quit), key: "q"))

        statusItem.menu = menu
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    func menuWillOpen(_ menu: NSMenu) {
        dateItem.title = "Pad shows: " + store.state.padDay.longDescription
        keepOnTopItem.state = store.state.keepOnTop ? .on : .off
    }

    @objc private func showPad() { pad.show() }

    @objc private func toggleKeepOnTop() {
        store.state.keepOnTop.toggle()
        store.save()
        pad.applyLevel()
    }

    @objc private func resetPosition() { pad.resetPosition() }

    @objc private func showAbout() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
