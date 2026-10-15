import SwiftUI

/// The paper ground (#180, step 1): the off-white of the app icon instead of the system grey, so
/// the app reads as the icon continued. Lists get hairlines on it, not white cards (rule 3).
/// Sheets keep the system background. On iPad and Mac the sidebar style stays; only the ground changes.
enum Paper {
    static let ground = Color("Paper")
}

extension View {
    /// A list on paper: plain with hairlines on iPhone, the platform style elsewhere.
    func paperList() -> some View {
        modifier(PaperList())
    }

    /// A row of a paper list. Plain rows paint their own background, so they take the ground too.
    func paperRow() -> some View {
        modifier(PaperRow())
    }

    /// Small, grey, spaced capitals, like the heads of the start screen's zones: the detail's section
    /// heads take them too (#438).
    func captionHead() -> some View {
        font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .tracking(1)
            .foregroundStyle(.secondary)
    }

    /// Paper behind a grouped form; its sections stay cards until the detail is reworked (#180, step 2).
    func paperGround() -> some View {
        scrollContentBackground(.hidden)
            .background(Paper.ground)
    }
}

private struct PaperList: ViewModifier {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS)
        if sizeClass == .compact {
            content
                .listStyle(.plain)
                .paperGround()
        } else {
            content.paperGround()
        }
        #else
        content.paperGround()
        #endif
    }
}

private struct PaperRow: ViewModifier {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    /// Only the compact list is plain; a sidebar row keeps its selection highlight.
    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS)
        if sizeClass == .compact {
            content.listRowBackground(Paper.ground)
        } else {
            content
        }
        #else
        content
        #endif
    }
}
