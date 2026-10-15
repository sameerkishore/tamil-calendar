import RasiCore
import SwiftUI

/// What a block gets to draw with: the day's data plus its own parameters from the layout.
/// Size and language come from the `cardTheme` environment.
struct BlockContext {
    let day: DayContext
    let params: [String: String]
}

/// One self-contained piece of a card (big date, timings, a note…).
/// To add a block: write a view conforming to this, then add it to `BlockRegistry.blocks`.
protocol CardBlock: View {
    /// The name layouts use for this block, e.g. "timings".
    static var type: String { get }
    /// Shown in a future layout editor.
    static var displayName: String { get }
    init(_ context: BlockContext)
}

@MainActor
enum BlockRegistry {
    static let blocks: [any CardBlock.Type] = [
        GregorianDateBlock.self,
        TamilDateBlock.self,
        TimingsBlock.self,
        SunTimesBlock.self,
        ComingSoonBlock.self,
        NoteBlock.self,
        FooterBlock.self,
    ]

    private static let byType: [String: any CardBlock.Type] =
        Dictionary(uniqueKeysWithValues: blocks.map { ($0.type, $0) })

    static func view(for spec: CardLayout.BlockSpec, context: DayContext) -> AnyView {
        guard let block = byType[spec.type] else {
            // Unknown blocks (e.g. from a newer layout file) leave a gap rather than failing.
            return AnyView(EmptyView())
        }
        return AnyView(block.init(BlockContext(day: context, params: spec.params)))
    }
}
