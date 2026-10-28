import AppKit
import Carbon.HIToolbox

/// The system-wide shortcut that brings the calendar in front of all windows or sends it back
/// to the desktop. Carbon hot keys work from any app and need no accessibility permission.
enum FrontShortcut: String, Codable, CaseIterable {
    case controlH
    case controlOptionH
    case controlCommandH
    case off

    var title: String {
        switch self {
        case .controlH: "⌃H"
        case .controlOptionH: "⌃⌥H"
        case .controlCommandH: "⌃⌘H"
        case .off: "Off"
        }
    }

    /// For showing the shortcut next to the menu item.
    var menuModifiers: NSEvent.ModifierFlags? {
        switch self {
        case .controlH: [.control]
        case .controlOptionH: [.control, .option]
        case .controlCommandH: [.control, .command]
        case .off: nil
        }
    }

    fileprivate var carbonModifiers: UInt32? {
        switch self {
        case .controlH: UInt32(controlKey)
        case .controlOptionH: UInt32(controlKey | optionKey)
        case .controlCommandH: UInt32(controlKey | cmdKey)
        case .off: nil
        }
    }
}

/// The system-wide shortcut that moves the board on to the next picture.
enum PictureShortcut: String, Codable, CaseIterable {
    case controlJ
    case controlOptionJ
    case controlCommandJ
    case off

    var title: String {
        switch self {
        case .controlJ: "⌃J"
        case .controlOptionJ: "⌃⌥J"
        case .controlCommandJ: "⌃⌘J"
        case .off: "Off"
        }
    }

    var menuModifiers: NSEvent.ModifierFlags? {
        switch self {
        case .controlJ: [.control]
        case .controlOptionJ: [.control, .option]
        case .controlCommandJ: [.control, .command]
        case .off: nil
        }
    }

    fileprivate var carbonModifiers: UInt32? {
        switch self {
        case .controlJ: UInt32(controlKey)
        case .controlOptionJ: UInt32(controlKey | optionKey)
        case .controlCommandJ: UInt32(controlKey | cmdKey)
        case .off: nil
        }
    }
}

/// One system-wide shortcut. Each instance has its own id, so several can be registered at once.
@MainActor
final class HotKey {
    private var ref: EventHotKeyRef?
    private let id: UInt32
    private static var actions: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var handlerInstalled = false

    init() {
        id = Self.nextID
        Self.nextID += 1
    }

    /// Registers `shortcut` (replacing any previous one) to run `action`.
    func register(_ shortcut: FrontShortcut, action: @escaping () -> Void) {
        register(key: kVK_ANSI_H, modifiers: shortcut.carbonModifiers, title: shortcut.title, action: action)
    }

    func register(_ shortcut: PictureShortcut, action: @escaping () -> Void) {
        register(key: kVK_ANSI_J, modifiers: shortcut.carbonModifiers, title: shortcut.title, action: action)
    }

    private func register(key: Int, modifiers: UInt32?, title: String, action: @escaping () -> Void) {
        unregister()
        guard let modifiers else { return }
        Self.actions[id] = action
        Self.installHandlerOnce()
        let hotKeyID = EventHotKeyID(signature: OSType(0x5241_5350), id: id) // 'RASP'
        let status = RegisterEventHotKey(UInt32(key), modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &ref)
        if status != noErr {
            NSLog("RasiPalan: couldn't register hot key \(title) (\(status)); another app may be using it")
        }
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
        Self.actions[id] = nil
    }

    private static func installHandlerOnce() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            // Carbon delivers hot keys on the main thread.
            MainActor.assumeIsolated { HotKey.actions[hotKeyID.id]?() }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
