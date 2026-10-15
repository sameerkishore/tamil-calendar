import AppKit
import RasiCore

/// The menu-bar icon and its menu. The app has no Dock icon, so this is its only chrome.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let app: AppController
    private let pad: PadWindowController
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    private let dateItem = NSMenuItem()
    private let tamilDateItem = NSMenuItem()
    private let keepOnTopItem = NSMenuItem()
    private let soundItem = NSMenuItem()
    private let locationItem = NSMenuItem()
    private let automaticLocationItem = NSMenuItem()
    private let chooseCityItem = NSMenuItem()
    private var styleItems: [PanchangamStyle: NSMenuItem] = [:]
    private var languageItems: [CardLanguage: NSMenuItem] = [:]
    private var sizeItems: [(CGFloat, NSMenuItem)] = []
    private static let sizePresets: [(String, CGFloat)] = [
        ("Tiny (50%)", 0.5), ("Small (75%)", 0.75), ("Normal (100%)", 1), ("Large (150%)", 1.5),
        ("Extra Large (200%)", 2), ("Huge (250%)", 2.5),
    ]

    init(app: AppController, pad: PadWindowController) {
        self.app = app
        self.pad = pad
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Rasi Palan")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        menu.delegate = self

        dateItem.isEnabled = false
        tamilDateItem.isEnabled = false
        menu.addItem(dateItem)
        menu.addItem(tamilDateItem)
        menu.addItem(.separator())

        menu.addItem(item("Show Pad", #selector(showPad)))
        menu.addItem(item(keepOnTopItem, "Keep Pad Above Windows", #selector(toggleKeepOnTop)))
        menu.addItem(item("Reset Pad Position", #selector(resetPosition)))
        menu.addItem(item("Clear Desktop (torn sheets and balls)", #selector(clearDesktop)))
        menu.addItem(.separator())
        menu.addItem(item("Templates & Board…", #selector(showGallery)))

        let sizeMenu = NSMenu()
        sizeMenu.addItem(item("Bigger", #selector(bigger), key: "+"))
        sizeMenu.addItem(item("Smaller", #selector(smaller), key: "-"))
        sizeMenu.addItem(.separator())
        for (title, scale) in Self.sizePresets {
            let sizeItem = item(title, #selector(chooseSize(_:)))
            sizeItem.representedObject = scale
            sizeItems.append((scale, sizeItem))
            sizeMenu.addItem(sizeItem)
        }
        sizeMenu.addItem(.separator())
        let tip = NSMenuItem(title: "Tip: ⌘-scroll or pinch over the pad", action: nil, keyEquivalent: "")
        tip.isEnabled = false
        sizeMenu.addItem(tip)
        let sizeRoot = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        sizeRoot.submenu = sizeMenu
        menu.addItem(sizeRoot)
        menu.addItem(.separator())

        locationItem.isEnabled = false
        menu.addItem(locationItem)
        menu.addItem(item(automaticLocationItem, "Use My Location", #selector(useMyLocation)))
        menu.addItem(item(chooseCityItem, "Choose City…", #selector(chooseCity)))
        menu.addItem(.separator())

        let styleMenu = NSMenu()
        for style in PanchangamStyle.allCases {
            let styleItem = NSMenuItem()
            styleItem.representedObject = style.rawValue
            styleItem.attributedTitle = Self.styleTitle(style)
            styleItem.action = #selector(chooseStyle(_:))
            styleItem.target = self
            styleItems[style] = styleItem
            styleMenu.addItem(styleItem)
        }
        let styleRoot = NSMenuItem(title: "Panchangam Style", action: nil, keyEquivalent: "")
        styleRoot.submenu = styleMenu
        menu.addItem(styleRoot)

        let languageMenu = NSMenu()
        for language in CardLanguage.allCases {
            let languageItem = item(language.menuTitle, #selector(chooseLanguage(_:)))
            languageItem.representedObject = language.rawValue
            languageItems[language] = languageItem
            languageMenu.addItem(languageItem)
        }
        let languageRoot = NSMenuItem(title: "Card Language", action: nil, keyEquivalent: "")
        languageRoot.submenu = languageMenu
        menu.addItem(languageRoot)

        #if DEBUG
        let debugMenu = NSMenu()
        debugMenu.addItem(item("Previous Day", #selector(previousDay), key: "["))
        debugMenu.addItem(item("Next Day", #selector(nextDay), key: "]"))
        debugMenu.addItem(item("Back to Today", #selector(backToToday)))
        let debugRoot = NSMenuItem(title: "Debug", action: nil, keyEquivalent: "")
        debugRoot.submenu = debugMenu
        menu.addItem(debugRoot)
        #endif

        menu.addItem(item(soundItem, "Sound Effects", #selector(toggleSound)))
        menu.addItem(item("Advanced Physics Settings…", #selector(showPhysics)))
        menu.addItem(.separator())
        menu.addItem(item("About Rasi Palan", #selector(showAbout)))
        menu.addItem(item("Quit Rasi Palan", #selector(quit), key: "q"))

        statusItem.menu = menu
    }

    private static func styleTitle(_ style: PanchangamStyle) -> NSAttributedString {
        let (title, detail) = switch style {
        case .traditional: ("Traditional (Vakyam)", "Matches printed Tamil Nadu calendars")
        case .precise: ("Precise (Thirukanitham)", "True sky and timings for your location")
        }
        let s = NSMutableAttributedString(string: title + "\n",
                                          attributes: [.font: NSFont.menuFont(ofSize: 0)])
        s.append(NSAttributedString(string: detail, attributes: [
            .font: NSFont.menuFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]))
        return s
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        item(NSMenuItem(), title, action, key: key)
    }

    private func item(_ item: NSMenuItem, _ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        item.title = title
        item.action = action
        item.keyEquivalent = key
        item.target = self
        return item
    }

    func menuWillOpen(_ menu: NSMenu) {
        let ctx = app.model.context
        dateItem.title = "Pad shows: " + ctx.day.longDescription
        tamilDateItem.title = "\(ctx.tamil.month.ta) \(ctx.tamil.day) · \(ctx.tamil.yearName.ta) "
            + "(\(ctx.tamil.month.en) \(ctx.tamil.day), \(ctx.tamil.yearName.en))"
        keepOnTopItem.state = app.state.keepOnTop ? .on : .off
        soundItem.state = app.state.soundEnabled ? .on : .off

        let source = app.state.locationSource
        let suffix = switch source {
        case .automatic: "from your Mac's location"
        case .manual: "chosen by you"
        case .timeZone: "from your time zone"
        }
        locationItem.title = "Location: \(ctx.location.name) (\(suffix))"
        automaticLocationItem.state = source == .manual ? .off : .on
        chooseCityItem.state = source == .manual ? .on : .off

        for (style, styleItem) in styleItems {
            styleItem.state = app.state.style == style ? .on : .off
        }
        for (language, languageItem) in languageItems {
            languageItem.state = app.state.language == language ? .on : .off
        }
        for (scale, sizeItem) in sizeItems {
            sizeItem.state = abs(pad.scale - scale) < 0.01 ? .on : .off
        }
    }

    @objc private func showPad() { pad.show() }

    @objc private func toggleKeepOnTop() {
        app.setKeepOnTop(!app.state.keepOnTop)
    }

    @objc private func showPhysics() { app.showPhysicsSettings() }

    @objc private func toggleSound() {
        app.setSoundEnabled(!app.state.soundEnabled)
    }

    @objc private func resetPosition() { pad.resetPosition() }
    @objc private func clearDesktop() { app.clearDesktop() }
    @objc private func showGallery() { app.showGallery() }
    @objc private func useMyLocation() { app.useAutomaticLocation() }
    @objc private func chooseCity() { app.chooseCity() }

    @objc private func chooseStyle(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let style = PanchangamStyle(rawValue: raw) {
            app.setStyle(style)
        }
    }

    @objc private func chooseLanguage(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let language = CardLanguage(rawValue: raw) {
            app.setLanguage(language)
        }
    }

    @objc private func bigger() { pad.setScale(pad.scale * 1.15) }
    @objc private func smaller() { pad.setScale(pad.scale / 1.15) }

    @objc private func chooseSize(_ sender: NSMenuItem) {
        if let scale = sender.representedObject as? CGFloat { pad.setScale(scale) }
    }

    @objc private func previousDay() { app.shiftPadDay(by: -1) }
    @objc private func nextDay() { app.shiftPadDay(by: 1) }
    @objc private func backToToday() { app.resetPadDayToToday() }

    @objc private func showAbout() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
