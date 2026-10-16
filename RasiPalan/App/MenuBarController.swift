import AppKit
import RasiCore
import Sparkle

/// The menu-bar icon and its short menu; everything else lives in Settings. Also installs the
/// app's hidden main menu, so standard shortcuts (⌘, ⌘Q ⌘W, copy/paste) work in its windows.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let app: AppController
    private let pad: PadWindowController
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    /// Sparkle: checks the GitHub appcast daily and offers Install and Relaunch.
    private let updater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    private let dateItem = NSMenuItem()
    private let tamilDateItem = NSMenuItem()
    private let behindItem = NSMenuItem()
    private let frontItem = NSMenuItem()
    private let putBackItem = NSMenuItem()
    private let todayItem = NSMenuItem()

    init(app: AppController, pad: PadWindowController) {
        self.app = app
        self.pad = pad
        super.init()

        if let button = statusItem.button {
            button.image = Self.statusIcon()
        }

        let menu = NSMenu()
        menu.delegate = self
        for info in [dateItem, tamilDateItem, behindItem] {
            info.isEnabled = false
            menu.addItem(info)
        }
        menu.addItem(.separator())
        menu.addItem(item(putBackItem, "Put Sheet Back", #selector(putSheetBack), key: "z"))
        menu.addItem(item(todayItem, "Back to Today", #selector(backToToday), key: "t"))
        menu.addItem(item(frontItem, "Calendar in Front", #selector(toggleFront)))
        menu.addItem(item(NSMenuItem(), "Templates & Board…", #selector(showGallery)))
        menu.addItem(item(NSMenuItem(), "Clear Desktop", #selector(clearDesktop)))
        menu.addItem(.separator())

        #if DEBUG
        let debugMenu = NSMenu()
        debugMenu.addItem(item(NSMenuItem(), "Previous Day", #selector(previousDay), key: "["))
        debugMenu.addItem(item(NSMenuItem(), "Next Day", #selector(nextDay), key: "]"))
        let debugRoot = NSMenuItem(title: "Debug", action: nil, keyEquivalent: "")
        debugRoot.submenu = debugMenu
        menu.addItem(debugRoot)
        #endif

        menu.addItem(item(NSMenuItem(), "About Tamil Calendar", #selector(showAbout)))
        menu.addItem(item(NSMenuItem(), "Check for Updates…", #selector(checkForUpdates)))
        menu.addItem(item(NSMenuItem(), "Settings…", #selector(showSettings), key: ","))
        menu.addItem(item(NSMenuItem(), "Quit Tamil Calendar", #selector(quit), key: "q"))
        statusItem.menu = menu

        installMainMenu()
    }

    /// The app icon redrawn as a template image (band, sheet outline and த), so the menu bar
    /// tints it for light, dark and highlighted states. Drawn on demand, crisp at any scale.
    private static func statusIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let sheet = NSRect(x: 1.5, y: 1.5, width: 15, height: 15)
            let radius: CGFloat = 3.5
            let band: CGFloat = 4
            NSColor.black.set()

            let outline = NSBezierPath(roundedRect: sheet.insetBy(dx: 0.6, dy: 0.6), xRadius: radius - 0.6, yRadius: radius - 0.6)
            outline.lineWidth = 1.2
            outline.stroke()

            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: sheet, xRadius: radius, yRadius: radius).addClip()
            NSRect(x: sheet.minX, y: sheet.maxY - band, width: sheet.width, height: band).fill()
            NSGraphicsContext.restoreGraphicsState()

            let font = NSFont(name: "TamilSangamMN-Bold", size: 10) ?? .boldSystemFont(ofSize: 10)
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: "த", attributes: [.font: font]))
            let glyph = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
            let paper = NSRect(x: sheet.minX, y: sheet.minY, width: sheet.width, height: sheet.height - band)
            let ctx = NSGraphicsContext.current!.cgContext
            ctx.textPosition = CGPoint(x: paper.midX - glyph.midX, y: paper.midY - glyph.midY)
            CTLineDraw(line, ctx)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Tamil Calendar"
        return image
    }

    private func item(_ item: NSMenuItem, _ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        item.title = title
        item.action = action
        item.keyEquivalent = key
        item.target = self
        return item
    }

    /// Menu-bar apps have no visible main menu, but its key equivalents still work while one of
    /// the app's windows is focused.
    private func installMainMenu() {
        let main = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(item(NSMenuItem(), "About Tamil Calendar", #selector(showAbout)))
        appMenu.addItem(item(NSMenuItem(), "Check for Updates…", #selector(checkForUpdates)))
        appMenu.addItem(.separator())
        appMenu.addItem(item(NSMenuItem(), "Settings…", #selector(showSettings), key: ","))
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Tamil Calendar", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(item(NSMenuItem(), "Quit Tamil Calendar", #selector(quit), key: "q"))
        let appRoot = NSMenuItem()
        appRoot.submenu = appMenu
        main.addItem(appRoot)

        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editRoot = NSMenuItem()
        editRoot.submenu = edit
        main.addItem(editRoot)

        let window = NSMenu(title: "Window")
        window.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let windowRoot = NSMenuItem()
        windowRoot.submenu = window
        main.addItem(windowRoot)

        NSApp.mainMenu = main
    }

    func menuWillOpen(_ menu: NSMenu) {
        let ctx = app.model.context
        dateItem.title = ctx.day.longDescription
        tamilDateItem.title = "\(ctx.tamil.month.ta) \(ctx.tamil.day) · \(ctx.tamil.yearName.ta)"
        let behind = ctx.day.days(to: .today())
        behindItem.isHidden = behind <= 0
        behindItem.title = behind == 1 ? "1 day behind today: time to tear!" : "\(behind) days behind today: time to tear!"

        putBackItem.isHidden = !app.canPutSheetBack
        todayItem.isHidden = ctx.day == .today()
        frontItem.state = app.state.keepOnTop ? .on : .off
        // Show the system-wide shortcut beside it (pressing it here works too).
        if let mods = app.state.frontShortcut.menuModifiers {
            frontItem.keyEquivalent = "h"
            frontItem.keyEquivalentModifierMask = mods
        } else {
            frontItem.keyEquivalent = ""
        }
    }

    @objc private func putSheetBack() { app.putSheetBack() }
    @objc private func toggleFront() { app.toggleInFront() }
    @objc private func showGallery() { app.showGallery() }
    @objc private func clearDesktop() { app.clearDesktop() }
    @objc private func showSettings() { app.showSettings() }

    /// Menu-bar apps aren't frontmost, so bring Sparkle's window forward with us.
    @objc private func checkForUpdates() {
        NSApp.activate()
        updater.checkForUpdates(nil)
    }

    /// The standard About panel; the copyright line comes from Info.plist.
    @objc private func showAbout() {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let credits = NSAttributedString(
            string: "Made with ❤️ by Sameer (and Claude)\n\nPaper sounds, artwork and almanac all made in code.\nThirukkural couplets by Thiruvalluvar.",
            attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                         .foregroundColor: NSColor.secondaryLabelColor,
                         .paragraphStyle: style])
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }
    @objc private func previousDay() { app.shiftPadDay(by: -1) }
    @objc private func nextDay() { app.shiftPadDay(by: 1) }
    @objc private func backToToday() { app.resetPadDayToToday() }
    @objc private func quit() { NSApp.terminate(nil) }
}
