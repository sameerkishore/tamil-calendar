import AppKit
import EventKit
import RasiCore
import SwiftUI

/// Settings (⌘,): every option in one place. Everything applies immediately.
@MainActor
final class SettingsWindowController {
    private let window: NSWindow

    init(app: AppController) {
        window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 520, height: 720),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Tamil Calendar Settings"
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
    @State private var shortcut: FrontShortcut
    @State private var sound: Bool
    @State private var binColor: BinColor
    @State private var openAtLogin: Bool
    @State private var confirmToday = false
    @State private var myRasi: Int?
    @State private var signs: SignNames
    @State private var remindersAccess: PersonalDataService.Access = .notAsked
    @State private var calendarAccess: PersonalDataService.Access = .notAsked
    @State private var calendars: [EKCalendar] = []
    @State private var chosenCalendars: Set<String>?

    init(app: AppController, model: PadModel) {
        self.app = app
        self.model = model
        _language = State(initialValue: app.state.language)
        _style = State(initialValue: app.state.style)
        _shortcut = State(initialValue: app.state.frontShortcut)
        _myRasi = State(initialValue: app.state.myRasi)
        _signs = State(initialValue: app.state.signNames)
        _chosenCalendars = State(initialValue: app.state.eventCalendarIDs.map(Set.init))
        _sound = State(initialValue: app.state.soundEnabled)
        _binColor = State(initialValue: app.state.binColor)
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
                    HStack {
                        Button("Open Gallery…") { app.showGallery() }
                        Button("Customize Sheet…") { app.showLayoutEditor() }
                    }
                }
                Picker("Paper", selection: Binding(get: { model.paperChoice }, set: { app.setPaperChoice($0) })) {
                    ForEach(PaperChoice.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .help("Prints the same sheet on light newsprint or dark card")
                LabeledContent("Size") {
                    HStack {
                        Slider(value: Binding(get: { Double(model.scale) },
                                              set: { app.setPadScale(CGFloat($0)) }),
                               in: 0.5...2.5)
                        Text("\(Int((model.scale * 100).rounded()))%").monospacedDigit().frame(width: 44, alignment: .trailing)
                    }
                }
            }

            Section {
                Picker("Sign names", selection: $signs) {
                    Text("Tamil rasi").tag(SignNames.tamil)
                    Text("Western zodiac").tag(SignNames.western)
                }
                .pickerStyle(.segmented)
                SignPicker(title: "Your sign", sign: $myRasi, names: signs)
                Text("Horoscope lines are written into the app, not fetched: two stock lines a day for your sign, the same for a given date. For fun only.")
                    .font(.caption).foregroundStyle(.secondary)
                accessRow("Reminders", access: remindersAccess, type: .reminder)
                accessRow("Calendars", access: calendarAccess, type: .event)
                if calendarAccess == .granted && !calendars.isEmpty {
                    DisclosureGroup("Calendars to print") {
                        ForEach(calendars, id: \.calendarIdentifier) { cal in
                            Toggle(isOn: calendarBinding(cal.calendarIdentifier)) {
                                HStack(spacing: 6) {
                                    Circle().fill(Color(cgColor: cal.cgColor)).frame(width: 9, height: 9)
                                    Text(cal.title)
                                }
                            }
                        }
                    }
                }
                Text("Weather comes from Open-Meteo, a free service. Only your city's rounded location is sent, and only while a Weather block is on your sheet.")
                    .font(.caption).foregroundStyle(.secondary)
            } header: {
                Text("Personal blocks")
            } footer: {
                Text("Add Horoscope, Reminders, Events or Weather blocks with Customize Sheet. They're read-only and printed for each sheet's own date.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Desktop") {
                Toggle("Calendar in front of all windows", isOn: Binding(get: { model.keepOnTop },
                                                                          set: { app.setKeepOnTop($0) }))
                Picker("Shortcut to bring it in front / send it back", selection: $shortcut) {
                    ForEach(FrontShortcut.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                if shortcut == .controlH {
                    Text("Works from any app. In some text editors and Terminal ⌃H also deletes a character; pick another if it gets in the way.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                LabeledContent("Lost the calendar?") {
                    Button("Reset Pad Position") { app.resetPadPosition() }
                }
                Toggle("Sound effects", isOn: $sound)
                Toggle("Open at login", isOn: $openAtLogin)
                LabeledContent("Tearing feel") {
                    Button("Advanced Physics Settings…") { app.showPhysicsSettings() }
                }
                LabeledContent("Torn sheets and paper balls") {
                    Button("Clear Desktop") { app.clearDesktop() }
                }
                LabeledContent("Bin color") {
                    HStack(spacing: 8) {
                        ForEach(BinColor.allCases, id: \.self) { color in
                            Button {
                                binColor = color
                                app.setBinColor(color)
                            } label: {
                                Circle().fill(color.plastic.base)
                                    .frame(width: 18, height: 18)
                                    .padding(3)
                                    .overlay(Circle().strokeBorder(binColor == color ? Color.accentColor : .clear, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                            .help(color.title)
                            .accessibilityLabel(color.title)
                            .accessibilityAddTraits(binColor == color ? .isSelected : [])
                        }
                    }
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

            Section {
                LabeledContent("Tamil Calendar",
                               value: "Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                Text("Paper sounds, artwork and almanac all made in code. Thirukkural couplets by Thiruvalluvar.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .onChange(of: language) { _, v in app.setLanguage(v) }
        .onChange(of: style) { _, v in app.setStyle(v) }
        .onChange(of: shortcut) { _, v in app.setFrontShortcut(v) }
        .onChange(of: myRasi) { _, v in app.setMyRasi(v) }
        .onChange(of: signs) { _, v in app.setSignNames(v) }
        .onAppear(perform: refreshAccess)
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

    private func refreshAccess() {
        guard let personal = app.personal else { return }
        remindersAccess = personal.access(for: .reminder)
        calendarAccess = personal.access(for: .event)
        calendars = personal.eventCalendars()
    }

    @ViewBuilder
    private func accessRow(_ title: String, access: PersonalDataService.Access, type: EKEntityType) -> some View {
        LabeledContent(title) {
            switch access {
            case .granted:
                Label("Allowed", systemImage: "checkmark.circle").foregroundStyle(.green)
            case .notAsked:
                Button("Allow Access…") {
                    Task {
                        _ = await app.personal?.requestAccess(for: type)
                        refreshAccess()
                        app.personal?.refresh()
                    }
                }
            case .denied:
                Button("Open Privacy Settings…") {
                    let pane = type == .reminder ? "Privacy_Reminders" : "Privacy_Calendars"
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!)
                }
            }
        }
    }

    /// nil selection means "all calendars"; ticking boxes switches to an explicit list.
    private func calendarBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { chosenCalendars?.contains(id) ?? true },
            set: { on in
                var set = chosenCalendars ?? Set(calendars.map(\.calendarIdentifier))
                if on { set.insert(id) } else { set.remove(id) }
                chosenCalendars = set
                app.setEventCalendars(Array(set))
            })
    }
}
