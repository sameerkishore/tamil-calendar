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

@MainActor
final class HotKey {
    private var ref: EventHotKeyRef?
    private static var action: (() -> Void)?
    private static var handlerInstalled = false

    /// Registers `shortcut` (replacing any previous one) to run `action`.
    func register(_ shortcut: FrontShortcut, action: @escaping () -> Void) {
        unregister()
        guard let modifiers = shortcut.carbonModifiers else { return }
        Self.action = action
        Self.installHandlerOnce()
        let id = EventHotKeyID(signature: OSType(0x5241_5350), id: 1) // 'RASP'
        let status = RegisterEventHotKey(UInt32(kVK_ANSI_H), modifiers, id, GetEventDispatcherTarget(), 0, &ref)
        if status != noErr {
            NSLog("RasiPalan: couldn't register hot key \(shortcut.title) (\(status)); another app may be using it")
        }
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
    }

    private static func installHandlerOnce() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, _, _ in
            // Carbon delivers hot keys on the main thread.
            MainActor.assumeIsolated { HotKey.action?() }
            return noErr
        }, 1, &spec, nil, nil)
    }
}

