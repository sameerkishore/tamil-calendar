import Foundation
import RasiCore
import SwiftUI

/// A card layout is data: a stack of rows, each holding one or more blocks side by side.
/// Templates ship as JSON in Resources/Layouts; a future layout editor only has to edit this.
///
/// ```json
/// { "id": "classic", "name": "Classic", "rows": [
///     { "blocks": ["gregorianDate", "tamilDate"], "separators": true, "height": 200, "ruleBelow": true },
///     { "blocks": [{ "type": "note", "params": { "text": "Call Amma" } }], "top": 8 },
///     { "flex": true },
///     { "blocks": ["footer"] } ] }
/// ```
struct CardLayout: Codable, Identifiable {
    var id: String
    var name: String
    var rows: [Row]

    struct Row: Codable {
        var blocks: [BlockSpec] = []
        /// Vertical rules between blocks.
        var separators: Bool = false
        /// Fixed height in sheet points; otherwise the row hugs its content.
        var height: CGFloat?
        /// Takes up the remaining space (pushes later rows to the bottom).
        var flex: Bool = false
        /// Horizontal rule under the row.
        var ruleBelow: Bool = false
        /// Space above the row, in sheet points.
        var top: CGFloat = 0

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            blocks = try c.decodeIfPresent([BlockSpec].self, forKey: .blocks) ?? []
            separators = try c.decodeIfPresent(Bool.self, forKey: .separators) ?? false
            height = try c.decodeIfPresent(CGFloat.self, forKey: .height)
            flex = try c.decodeIfPresent(Bool.self, forKey: .flex) ?? false
            ruleBelow = try c.decodeIfPresent(Bool.self, forKey: .ruleBelow) ?? false
            top = try c.decodeIfPresent(CGFloat.self, forKey: .top) ?? 0
        }
    }

    /// A block by type, with optional string parameters. Written in JSON either as just
    /// `"timings"` or as `{ "type": "note", "params": { "text": "…" } }`.
    struct BlockSpec: Codable {
        var type: String
        var params: [String: String] = [:]

        init(from decoder: Decoder) throws {
            if let type = try? decoder.singleValueContainer().decode(String.self) {
                self.type = type
                return
            }
            let c = try decoder.container(keyedBy: CodingKeys.self)
            type = try c.decode(String.self, forKey: .type)
            params = try c.decodeIfPresent([String: String].self, forKey: .params) ?? [:]
        }
    }

    /// All layouts bundled with the app, by id.
    static let bundled: [String: CardLayout] = {
        let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "Layouts") ?? []
        var layouts: [String: CardLayout] = [:]
        for url in urls {
            do {
                let layout = try JSONDecoder().decode(CardLayout.self, from: Data(contentsOf: url))
                layouts[layout.id] = layout
            } catch {
                NSLog("RasiPalan: bad layout \(url.lastPathComponent): \(error)")
            }
        }
        return layouts
    }()

    static var classic: CardLayout { bundled["classic"]! }
}

/// Draws a layout's rows for one day. Contains no knowledge of individual blocks.
struct CardSheetView: View {
    let layout: CardLayout
    let context: DayContext
    @Environment(\.cardTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(layout.rows.enumerated()), id: \.offset) { _, row in
                if row.flex {
                    Spacer(minLength: 0)
                } else {
                    rowView(row)
                }
            }
        }
        .foregroundStyle(Ink.black)
    }

    @ViewBuilder
    private func rowView(_ row: CardLayout.Row) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(row.blocks.enumerated()), id: \.offset) { i, spec in
                    if i > 0 && row.separators {
                        Rectangle().fill(Ink.black)
                            .frame(width: max(1, theme.u(1)))
                            .padding(.vertical, theme.u(6))
                    }
                    BlockRegistry.view(for: spec, context: context)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: row.height.map(theme.u))
            .padding(.top, theme.u(row.top))

            if row.ruleBelow {
                Rectangle().fill(Ink.black)
                    .frame(height: max(1, theme.u(1)))
                    .padding(.horizontal, theme.u(10))
            }
        }
    }
}
