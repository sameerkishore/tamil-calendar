import AppKit
import RasiCore
import SwiftUI

/// Settings (⌘,): every option in one place. Everything applies immediately.
@MainActor
final class SettingsWindowController {
    private let window: NSWindow

    init(app: AppController) {
        window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 480, height: 600),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Rasi Palan Settings"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView(app: app, model: app.model))
    }

    func show() {
        window.center()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}

private struct SettingsView: View {
    let app: AppController
    let model: PadModel

    @State private var language: CardLanguage
    @State private var style: PanchangamStyle
    @State private var keepOnTop: Bool
    @State private var sound: Bool
    @State private var openAtLogin: Bool
    @State private var confirmToday = false

    init(app: AppController, model: PadModel) {
        self.app = app
        self.model = model
        _language = State(initialValue: app.state.language)
        _style = State(initialValue: app.state.style)
        _keepOnTop = State(initialValue: app.state.keepOnTop)
        _sound = State(initialValue: app.state.soundEnabled)
        _openAtLogin = State(initialValue: app.opensAtLogin)
    }

    var body: some View {
        Form {
            Section("Calendar") {
                Picker("Card language", selection: $language) {
                    ForEach(CardLanguage.allCases, id: \.self) { Text($0.menuTitle).tag($0) }
                }
                Picker("Panchangam style", selection: $style) {
                    Text("Traditional (Vakyam)").tag(PanchangamStyle.traditional)
                    Text("Precise (Thirukanitham)").tag(PanchangamStyle.precise)
                }
                Text(style == .traditional
                     ? "Matches printed Tamil Nadu calendars."
                     : "True sky, with timings worked out for your location.")
                    .font(.caption).foregroundStyle(.secondary)
                LabeledContent("Location") {
                    HStack {
                        Text(model.context.location.name)
                        Button("Use My Location") { app.useAutomaticLocation() }
                        Button("Choose City…") { app.chooseCity() }
                    }
                }
            }

            Section("Look") {
                LabeledContent("Templates & board") {
                    Button("Open Gallery…") { app.showGallery() }
                }
                LabeledContent("Size") {
                    HStack {
                        Slider(value: Binding(get: { Double(model.scale) },
                                              set: { app.setPadScale(CGFloat($0)) }),
                               in: 0.5...2.5)
                        Text("\(Int((model.scale * 100).rounded()))%").monospacedDigit().frame(width: 44, alignment: .trailing)
                    }
                }
            }

            Section("Desktop") {
                Toggle("Keep pad above other windows", isOn: $keepOnTop)
                Toggle("Sound effects", isOn: $sound)
                Toggle("Open at login", isOn: $openAtLogin)
                LabeledContent("Tearing feel") {
                    Button("Advanced Physics Settings…") { app.showPhysicsSettings() }
                }
                LabeledContent("Torn sheets and paper balls") {
                    Button("Clear Desktop") { app.clearDesktop() }
                }
            }

            Section("Pad") {
                LabeledContent("Showing") {
                    Text(model.context.day.longDescription)
                }
                LabeledContent("Skip ahead to today") {
                    Button("Set Pad to Today…") { confirmToday = true }
                        .disabled(model.context.day >= CalendarDay.today())
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .onChange(of: language) { _, v in app.setLanguage(v) }
        .onChange(of: style) { _, v in app.setStyle(v) }
        .onChange(of: keepOnTop) { _, v in app.setKeepOnTop(v) }
        .onChange(of: sound) { _, v in app.setSoundEnabled(v) }
        .onChange(of: openAtLogin) { _, v in
            app.setOpensAtLogin(v)
            openAtLogin = app.opensAtLogin
        }
        .confirmationDialog("Jump the pad to today without tearing?", isPresented: $confirmToday) {
            Button("Set Pad to Today") { app.resetPadDayToToday() }
        } message: {
            Text("The sheets in between are skipped rather than torn off.")
        }
    }
}
