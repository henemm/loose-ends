import SwiftData
import SwiftUI

/// Placeholder navigation until the screens from the design canvas are built.
/// One code path for iPhone, iPad and Mac (ADR-1).
struct ContentView: View {
    @Query(sort: \TaskItem.capturedAt, order: .reverse) private var tasks: [TaskItem]
    @State private var selection: ViewKind? = .next

    var body: some View {
        NavigationSplitView {
            List(ViewKind.allCases.filter(\.isSystem), id: \.self, selection: $selection) { kind in
                HStack {
                    Text(String(localized: kind.titleKey))
                    Spacer()
                    Text("\(ViewRules.tasks(for: kind, in: tasks).count)")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Views")
        } detail: {
            if let selection {
                List(ViewRules.tasks(for: selection, in: tasks)) { task in
                    Text(task.displayTitle)
                }
                .navigationTitle(String(localized: selection.titleKey))
            } else {
                Text("Pick a view")
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(try! ModelContainerFactory.make(inMemory: true))
}
