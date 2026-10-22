import OSLog
import SwiftData
import SwiftUI

/// The words a tag learned from the user's own assignments (#233 Schnitt 2b), one per row, as the
/// user wrote them. A swipe strikes a word: it leaves the list at once and is never learned for this
/// tag again, on every device (`TaskContext.forgottenWords`). The list is computed from the tasks, so
/// a struck word is gone without any reload.
struct LearnedWordsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let context: TaskContext
    let tasks: [TaskItem]
    let contexts: [TaskContext]
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Catalog")

    private var words: [String] {
        EnrichmentCoordinator.recognizedWords(in: tasks, catalog: contexts)[context.name] ?? []
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(words, id: \.self) { word in
                        Text(word)
                            .fontDesign(.serif)
                            .accessibilityIdentifier("learnedWord_\(word)")
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { forget(word) } label: {
                                    Label("Forget", systemImage: "trash")
                                }
                                .accessibilityIdentifier("forgetWord_\(word)")
                            }
                    }
                } header: {
                    Text("Learned words")
                } footer: {
                    Text("A word you strike here is never learned for this tag again.")
                }
            }
            .navigationTitle(Text(verbatim: context.name))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("learnedWordsDoneButton")
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 360, minHeight: 300)
        #endif
    }

    private func forget(_ word: String) {
        CatalogService.forget(word, on: context)
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Forgetting a learned word failed: \(error, privacy: .public)")
        }
    }
}
