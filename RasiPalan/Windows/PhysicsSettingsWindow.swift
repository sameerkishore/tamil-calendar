import AppKit
import SwiftUI

/// "Advanced Physics Settings…": plain-language choices for how tearing feels.
/// Changes apply immediately, so people can try a tear and adjust.
@MainActor
final class PhysicsSettingsWindowController {
    private let window: NSWindow

    init(physics: TearPhysics, onChange: @escaping (TearPhysics) -> Void) {
        window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 460, height: 340),
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

            choice("Tear effort", "How far across the sheet you drag to tear it off.",
                   $physics.effort, [(.light, "Light"), (.medium, "Medium"), (.heavy, "Heavy")])

            choice("Perforation", "The row of holes along the top of each sheet: many small ones or a few big ones.",
                   $physics.perforation, [(.fine, "Fine"), (.standard, "Standard"), (.coarse, "Coarse")])

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Trackpad click", isOn: $physics.haptics)
                    .font(.headline)
                Text("Feel a click when the sheet comes off, on a Force Touch trackpad.")
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
