import AppKit
import SwiftUI

/// "Advanced Physics Settings…": plain-language choices for how tearing feels.
/// Changes apply immediately, so people can try a tear and adjust.
@MainActor
final class PhysicsSettingsWindowController {
    private let window: NSWindow

    init(physics: TearPhysics, onChange: @escaping (TearPhysics) -> Void) {
        window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 460, height: 520),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Advanced Physics Settings"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: PhysicsSettingsView(physics: physics, onChange: onChange))
    }

    func show() {
        window.center()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}

private struct PhysicsSettingsView: View {
    @State var physics: TearPhysics
    let onChange: (TearPhysics) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("How tearing a sheet feels. Try a tear after changing something — it takes effect right away.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            choice("Paper strength", "How hard you have to pull before the paper starts to tear.",
                   $physics.strength, [(.light, "Light"), (.medium, "Medium"), (.heavy, "Heavy")])

            choice("Perforation", "Fine tears in many small ticks; coarse in a few big, chunky ones.",
                   $physics.perforation, [(.fine, "Fine"), (.standard, "Standard"), (.coarse, "Coarse")])

            choice("Zip speed", "When you pull quickly, how fast the holes give way one after another.",
                   $physics.zipSpeed, [(.slow, "Slow"), (.normal, "Normal"), (.quick, "Quick")])

            choice("Paper feel", "How much the sheet bends while you pull. Real calendar paper is crisp.",
                   $physics.feel, [(.crisp, "Crisp"), (.flexible, "Flexible"), (.floppy, "Floppy")])

            choice("Swing", "How far a half-torn sheet swings on the corner that's still attached.",
                   $physics.swing, [(.little, "Little"), (.some, "Some"), (.lots, "Lots")])

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Trackpad clicks", isOn: $physics.haptics)
                    .font(.headline)
                Text("Feel a small click for each hole on a Force Touch trackpad.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Reset to Defaults") { physics = .defaults }
                    .disabled(physics == .defaults)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onChange(of: physics) { _, new in onChange(new) }
    }

    private func choice<T: Hashable>(_ title: String, _ help: String, _ value: Binding<T>,
                                     _ options: [(T, String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Picker(title, selection: value) {
                ForEach(options, id: \.0) { option in
                    Text(option.1).tag(option.0)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Text(help)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
