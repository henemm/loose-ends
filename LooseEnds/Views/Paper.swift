import SwiftUI

/// The paper ground (#180, step 1): the off-white of the app icon instead of the system grey, so
/// the app reads as the icon continued. Lists get hairlines on it, not white cards (rule 3).
/// Sheets keep the system background. On iPad and Mac the sidebar style stays; only the ground changes.
enum Paper {
    static let ground = Color("Paper")
    /// Rows of the detail in a wide window and on the Mac (#477): 20 pt beside, a little air above and below.
    static let wideRowInsets = EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)
    /// The review note's row there: its tint spans the lines' 20 pt, its text sits 12 pt inside the tint.
    static let wideNoteInsets = EdgeInsets(top: 10, leading: 32, bottom: 10, trailing: 32)
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

    /// A row of the task detail (#477): paper behind it on every size, so a wide window and the Mac
    /// show lines on paper instead of cards. In a compact window the same as `paperRow()`.
    func detailRow() -> some View {
        listRowBackground(Paper.ground)
    }

    /// The task detail in a wide window (#477): a centered column of at most
    /// `DetailLayout.columnWidth`, paper to the window's edges. No effect in a compact window.
    func detailColumn(wide: Bool) -> some View {
        modifier(DetailColumn(wide: wide))
    }

    /// A row of a list in a wide window (#477): the start screen's sizes, 11 pt above and below,
    /// paper behind it and grey under the pointer on the Mac. No effect in a compact window.
    /// `selected` marks the row chosen by the keys on the Mac in accent 12 % (#480); iOS ignores it.
    func wideListRow(selected: Bool = false) -> some View {
        modifier(WideListRow(selected: selected))
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

private struct DetailColumn: ViewModifier {
    let wide: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if wide {
            content
                .frame(maxWidth: DetailLayout.columnWidth)
                .frame(maxWidth: .infinity)
                .background(Paper.ground.ignoresSafeArea())
        } else {
            content
        }
    }
}

private struct WideListRow: ViewModifier {
    var selected = false
    @Environment(\.dynamicTypeSize) private var typeSize
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #else
    @State private var hovering = false
    #endif

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS)
        if sizeClass == .compact {
            content
        } else {
            wide(content).listRowBackground(Paper.ground)
        }
        #else
        wide(content)
            .onHover { hovering = $0 }
            // Grey 7 % from the ink itself, so light and dark take the same rule (#477). The chosen
            // row is accent 12 % and wins over the pointer (#480): accent = tappable or chosen.
            .listRowBackground(
                Paper.ground.overlay {
                    if selected {
                        RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.12))
                    } else if hovering {
                        RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.07))
                    }
                }
            )
        #endif
    }

    private func wide(_ content: Content) -> some View {
        let metrics = StartMetrics(typeSize)
        return content
            .padding(.vertical, 11)
            .environment(\.startMetrics, metrics)
            .startRow(metrics)
    }
}
