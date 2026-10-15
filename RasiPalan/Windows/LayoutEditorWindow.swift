import AppKit
import Observation
import RasiCore
import SwiftUI

/// "Customize Sheet…": build your own sheet from blocks, with a live preview.
/// Saving stores it as "My Layout" and switches the pad to it.
@MainActor
final class LayoutEditorWindowController {
    private let window: NSWindow

    init(app: AppController) {
        window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 940, height: 680),
                          styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "Customize Sheet"
        window.isReleasedWhenClosed = false
        window.contentMinSize = CGSize(width: 900, height: 620)
        let draft = LayoutDraft(from: app.model.layout)
        window.contentView = NSHostingView(rootView: LayoutEditorView(app: app, model: app.model, draft: draft,
                                                                      close: { [weak window] in window?.close() }))
    }

    func show() {
        window.center()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}

/// The layout being edited, in editor-friendly form.
@MainActor
@Observable
final class LayoutDraft {
    enum Header: String, CaseIterable { case twoColumn, bigDate, none }

    struct Item: Identifiable, Equatable {
        let id = UUID()
        var type: String
        var params: [String: String] = [:]
        /// Unchecked blocks stay in the list but aren't printed.
        var enabled = true
    }

    var header: Header
    var paper: PaperStock
    var items: [Item]
    var footer: Bool

    init(from layout: CardLayout) {
        header = .none
        paper = layout.paper
        items = []
        footer = false
        load(layout)
    }

    func load(_ layout: CardLayout) {
        paper = layout.paper
        var rows = layout.rows[...]
        header = .none
        if let first = rows.first {
            let types = first.blocks.map(\.type)
            if types == [GregorianDateBlock.type, TamilDateBlock.type] {
                header = .twoColumn
                rows = rows.dropFirst()
            } else if types == [BigDateBlock.type] {
                header = .bigDate
                rows = rows.dropFirst()
                // The big-date header brings its own Tamil date line and short rule.
                if rows.first?.blocks.map(\.type) == [TamilDateLineBlock.type] { rows = rows.dropFirst() }
                if rows.first?.blocks.map(\.type) == [RuleBlock.type] { rows = rows.dropFirst() }
            }
        }
        footer = rows.contains { $0.blocks.map(\.type) == [FooterBlock.type] }
        items = rows.filter { !$0.flex && $0.blocks.map(\.type) != [FooterBlock.type] }
            .flatMap(\.blocks)
            .filter { $0.type != ComingSoonBlock.type }
            .map { Item(type: $0.type, params: $0.params) }
    }

    var layout: CardLayout {
        var rows: [CardLayout.Row] = []
        switch header {
        case .twoColumn:
            rows.append(.init(blocks: [.init(GregorianDateBlock.type), .init(TamilDateBlock.type)],
                              separators: true, height: 186, ruleBelow: true))
        case .bigDate:
            rows.append(.init(blocks: [.init(BigDateBlock.type, ["size": "140"])], top: 4))
            rows.append(.init(blocks: [.init(TamilDateLineBlock.type)], top: 2))
            rows.append(.init(blocks: [.init(RuleBlock.type, ["width": "0.4"])], top: 10))
        case .none:
            break
        }
        for (i, item) in items.filter(\.enabled).enumerated() {
            rows.append(.init(blocks: [.init(item.type, item.params)], top: i == 0 ? 8 : 6))
        }
        rows.append(.init(flex: true))
        if footer { rows.append(.init(blocks: [.init(FooterBlock.type)])) }
        return CardLayout(id: CardLayout.customID, name: "My Layout",
                          summary: "Your own arrangement of blocks.", paper: paper, rows: rows)
    }
}

/// Blocks people can add, with a short note on each.
@MainActor private let addableBlocks: [(type: String, name: String, note: String)] = [
    (PanchangamBlock.type, "Tithi, star & yogam", "Like “பஞ்சமி … வரை  கேட்டை நாள் முழுவதும்”"),
    (ObservancesBlock.type, "Festivals & observances", "Festivals, fasts, birthdays and the day's direction"),
    (TimingsBlock.type, "Rahu Kalam & timings", "Rahu, Kuligai, Yamagandam"),
    (SunTimesBlock.type, "Sunrise & sunset", "With Soolam"),
    (NallaNeramBlock.type, "Good times", "நல்ல நேரம், chandrashtamam"),
    (HoroscopeBlock.type, "My horoscope", "Two lines for your rasi"),
    (RasiPalanBlock.type, "Rasi Palan grid", "One word for each of the 12 rasis"),
    (WeatherBlock.type, "Weather", "Forecast for your city"),
    (RemindersBlock.type, "Reminders due", "From the Reminders app, read-only"),
    (EventsBlock.type, "Calendar events", "From the calendars you choose"),
    (KuralBlock.type, "Thirukkural", "A couplet a day"),
    (NoteBlock.type, "Note", "Your own line of text"),
    (TamilDateLineBlock.type, "Tamil date (one line)", "புரட்டாசி 28 · பராபவ"),
    (RuleBlock.type, "Line", "A printed rule to separate sections"),
]

@MainActor private func blockName(_ type: String) -> String {
    addableBlocks.first { $0.type == type }?.name ?? type
}

private struct LayoutEditorView: View {
    let app: AppController
    let model: PadModel
    @Bindable var draft: LayoutDraft
    let close: () -> Void

    @State private var contentHeight: CGFloat = 0
    @State private var myRasi: Int?
    @State private var signs: SignNames

    init(app: AppController, model: PadModel, draft: LayoutDraft, close: @escaping () -> Void) {
        self.app = app
        self.model = model
        self.draft = draft
        self.close = close
        _myRasi = State(initialValue: app.state.myRasi)
        _signs = State(initialValue: app.state.signNames)
    }

    private func setAll(_ on: Bool) {
        for i in draft.items.indices { draft.items[i].enabled = on }
    }

    private let previewScale: CGFloat = 1.15

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            preview
                .padding(20)
                .frame(width: PadView.sheetSize.width * previewScale + 40)
            Divider()
            controls
        }
    }

    // MARK: Preview

    private var preview: some View {
        let layout = draft.layout
        let theme = CardTheme(scale: previewScale, language: model.language, perforations: model.perforations,
                              paper: layout.paper, myRasi: myRasi, signNames: signs)
        let available = PadView.sheetSize.height
        let fits = contentHeight <= available + 0.5
        return VStack(spacing: 12) {
            SheetFace(context: model.context, layout: layout, extras: model.extras[model.context.day])
                .environment(\.cardTheme, theme)
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                // Measure what the blocks need, at scale 1, without the flexible gap.
                .background(alignment: .top) {
                    CardSheetView(layout: CardLayout(id: "measure", name: "", paper: layout.paper,
                                                     rows: layout.rows.filter { !$0.flex }),
                                  context: model.context)
                        .environment(\.cardTheme, CardTheme(scale: 1, language: model.language, myRasi: myRasi,
                                                             signNames: signs))
                        .environment(\.sheetExtras, model.extras[model.context.day])
                        .frame(width: PadView.sheetSize.width)
                        .fixedSize(horizontal: false, vertical: true)
                        .background(GeometryReader { g in Color.clear.preference(key: HeightKey.self, value: g.size.height) })
                        .hidden()
                }
                .onPreferenceChange(HeightKey.self) { contentHeight = $0 }

            Label(fits ? "Everything fits on the sheet." : "Too much for one sheet: the last blocks will be cut off.",
                  systemImage: fits ? "checkmark.circle" : "exclamationmark.triangle")
                .font(.callout)
                .foregroundStyle(fits ? .green : .orange)
        }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section {
                    Menu("Start from a template…") {
                        ForEach(CardLayout.all) { layout in
                            Button(layout.name) { draft.load(layout) }
                        }
                    }
                    Picker("Header (dates)", selection: $draft.header) {
                        Text("Two columns").tag(LayoutDraft.Header.twoColumn)
                        Text("Big date").tag(LayoutDraft.Header.bigDate)
                        Text("None").tag(LayoutDraft.Header.none)
                    }
                    .pickerStyle(.segmented)
                    Picker("Paper", selection: $draft.paper) {
                        Text("Newsprint").tag(PaperStock.newsprint)
                        Text("Dark card").tag(PaperStock.dark)
                    }
                    .pickerStyle(.segmented)
                    Toggle("Footer (city and panchangam style)", isOn: $draft.footer)
                }

                Section {
                    List {
                        ForEach($draft.items) { $item in
                            // Capture the id now: reading `item` while removing it from the same
                            // array is an exclusivity violation (that was the crash).
                            BlockRow(item: $item, myRasi: $myRasi, signs: $signs, remove: { [id = item.id] in
                                draft.items.removeAll { $0.id == id }
                            })
                        }
                        .onMove { draft.items.move(fromOffsets: $0, toOffset: $1) }
                    }
                    .frame(minHeight: 260)
                    HStack {
                        Button("Uncheck All") { setAll(false) }
                        Button("Check All") { setAll(true) }
                        Spacer()
                        Button("Remove Unchecked") { draft.items.removeAll { !$0.enabled } }
                            .disabled(draft.items.allSatisfy(\.enabled))
                    }
                    Menu {
                        ForEach(addableBlocks, id: \.type) { block in
                            Button("\(block.name) — \(block.note)") {
                                draft.items.append(.init(type: block.type))
                            }
                        }
                    } label: {
                        Label("Add Block", systemImage: "plus")
                    }
                } header: {
                    Text("Blocks: tick what to print, drag to reorder")
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel", action: close)
                Spacer()
                Button("Use This Layout") {
                    if myRasi != app.state.myRasi { app.setMyRasi(myRasi) }
                    if signs != app.state.signNames { app.setSignNames(signs) }
                    app.saveCustomLayout(draft.layout)
                    close()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
    }
}

/// One block in the list, with its options.
private struct BlockRow: View {
    @Binding var item: LayoutDraft.Item
    @Binding var myRasi: Int?
    @Binding var signs: SignNames
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
                Toggle("", isOn: $item.enabled).labelsHidden().toggleStyle(.checkbox)
                Text(blockName(item.type)).font(.headline)
                    .foregroundStyle(item.enabled ? .primary : .secondary)
                Spacer()
                Button(role: .destructive, action: remove) { Image(systemName: "minus.circle") }
                    .buttonStyle(.borderless)
                    .help("Remove block")
            }
            if item.enabled {
                options
                    .padding(.leading, 44)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var options: some View {
        switch item.type {
        case NoteBlock.type:
            TextField("Text to print", text: param("text", ""))
            Toggle("Red ink", isOn: flag("ink", on: "red"))
        case TimingsBlock.type:
            Toggle("Rahu Kalam only", isOn: flag("only", on: "rahu"))
        case PanchangamBlock.type:
            Toggle("Show yogam", isOn: flag("yogam", on: "show", defaultOn: true))
        case ObservancesBlock.type:
            Toggle("Show the day's direction", isOn: flag("direction", on: "show", defaultOn: true))
        case NallaNeramBlock.type:
            Toggle("Show chandrashtamam", isOn: flag("chandrashtamam", on: "show", defaultOn: true))
        case RemindersBlock.type, EventsBlock.type:
            Stepper("Up to \(Int(item.params["max"] ?? "4") ?? 4) items", value: Binding(
                get: { Int(item.params["max"] ?? "4") ?? 4 },
                set: { item.params["max"] = String($0) }), in: 1...8)
        case HoroscopeBlock.type:
            Picker("Sign names", selection: $signs) {
                Text("Tamil rasi").tag(SignNames.tamil)
                Text("Western zodiac").tag(SignNames.western)
            }
            .pickerStyle(.segmented)
            SignPicker(title: "Your sign", sign: $myRasi, names: signs)
        default:
            EmptyView()
        }
    }

    private func param(_ key: String, _ fallback: String) -> Binding<String> {
        Binding(get: { item.params[key] ?? fallback }, set: { item.params[key] = $0 })
    }

    /// A toggle stored as a block parameter. Blocks treat "hide" as off for options that are on
    /// by default, so existing layouts keep working.
    private func flag(_ key: String, on: String, defaultOn: Bool = false) -> Binding<Bool> {
        Binding(
            get: { defaultOn ? item.params[key] != "hide" : item.params[key] == on },
            set: { newValue in
                if defaultOn { item.params[key] = newValue ? nil : "hide" } else { item.params[key] = newValue ? on : nil }
            })
    }
}

private struct HeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Picks one of the 12 signs, listed as Tamil rasis or Western zodiac signs.
struct SignPicker: View {
    let title: String
    @Binding var sign: Int?
    let names: SignNames

    var body: some View {
        Picker(title, selection: $sign) {
            Text("Choose…").tag(Int?.none)
            ForEach(0..<12, id: \.self) { i in
                Text(names == .western
                     ? "\(Zodiac.symbols[i]) \(Zodiac.western[i]) (\(RasiPalan.rasis[i].ta))"
                     : "\(RasiPalan.rasis[i].ta) (\(RasiPalan.rasis[i].en))")
                    .tag(Int?.some(i))
            }
        }
    }
}
