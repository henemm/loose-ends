import SwiftData
import SwiftUI

/// The page of all tags or all projects (#428, Henning 2026-10-15): reached from their line in the
/// iPhone index, a page of the same notebook. Every entry, the empty ones too, one tap to its list.
/// Long press renames, a swipe deletes after asking; "New tag" / "New project" closes the page.
struct CatalogPage: View {
    @Query(sort: \TaskContext.sortOrder) private var contexts: [TaskContext]
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    let kind: CatalogKind
    /// Every task; each entry counts its own.
    let tasks: [TaskItem]

    @State private var catalog = CatalogEditor()
    @State private var opened: ViewSelection?
    @State private var showsWords: TaskContext?

    private struct Entry: Identifiable {
        let id: String
        let name: String
        let count: Int
        let selection: ViewSelection
        let target: NameEdit.Target
        var context: TaskContext?
    }

    /// The learned words under each tag (#233 Schnitt 2b), as the user wrote them.
    private var recognized: [String: [String]] {
        kind == .tags ? EnrichmentCoordinator.recognizedWords(in: tasks, catalog: contexts) : [:]
    }

    private var entries: [Entry] {
        switch kind {
        case .tags:
            contexts.map { context in
                Entry(id: "contextRow_\(context.id.uuidString)", name: context.name,
                      count: ViewRules.tasks(inContext: context, in: tasks).count,
                      selection: .context(context.id), target: .context(context), context: context)
            }
        case .projects:
            projects.map { project in
                Entry(id: "projectRow_\(project.id.uuidString)", name: project.name,
                      count: ViewRules.tasks(inProject: project, in: tasks).count,
                      selection: .project(project.id), target: .project(project))
            }
        }
    }

    private var title: LocalizedStringKey { kind == .tags ? "Tags" : "Projects" }

    var body: some View {
        List {
            // The page's name as its heading, in New York like the start screen's sentence.
            Text(title)
                .font(.largeTitle)
                .fontDesign(.serif)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("catalogTitle")
                .listRowSeparator(.hidden)
                .paperRow()
            ForEach(entries) { entry in
                Button { opened = entry.selection } label: {
                    IndexLineLabel(title: entry.name, count: entry.count)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(entry.id)
                .catalogMenu(entry.target, in: catalog)
                .swipeActions { CatalogDeleteButton(target: entry.target, editor: catalog) }
                .listRowSeparator(.hidden)
                .paperRow()
                // What the tag learned from the user's own assignments (#233): one grey line, a tap
                // opens the words to strike one. Nothing learned, no line.
                if let context = entry.context, let words = recognized[entry.name], !words.isEmpty {
                    Button { showsWords = context } label: {
                        Text("Recognizes: \(words.joined(separator: ", "))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .padding(.bottom, 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("recognizedWords_\(context.id.uuidString)")
                    .listRowSeparator(.hidden)
                    .paperRow()
                }
            }
            newButton
                .padding(.top, 6)
                .listRowSeparator(.hidden)
                .paperRow()
        }
        .paperList()
        .navigationTitle(Text(verbatim: ""))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationDestination(item: $opened) { selection in
            TaskListView(selection: selection, tasks: tasks)
        }
        .sheet(item: $showsWords) { context in
            LearnedWordsSheet(context: context, tasks: tasks, contexts: contexts)
        }
        .catalogDialogs(catalog, contexts: contexts, projects: projects) { gone in
            if opened == gone { opened = nil }
        }
    }

    @ViewBuilder
    private var newButton: some View {
        switch kind {
        case .tags:
            Button("New tag", systemImage: "plus") { catalog.begin(NameEdit(target: .newContext)) }
                .accessibilityIdentifier("newContextButton")
        case .projects:
            Button("New project", systemImage: "plus") { catalog.begin(NameEdit(target: .newProject)) }
                .accessibilityIdentifier("newProjectButton")
        }
    }
}
