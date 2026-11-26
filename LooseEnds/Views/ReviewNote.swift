import SwiftUI

/// Why the task sits in "New", under the title of a detail opened from there (#349): the same
/// reason the list shows, plus what "Looks right" asks for. Grey on a breath of accent (ADR-14).
struct ReviewNote: View {
    let task: TaskItem
    /// Fields a rule or the AI set and the user has not touched since.
    let automaticFields: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            headline.fontWeight(.semibold)
            if let hint { hint.foregroundStyle(.secondary) }
        }
        .font(.footnote)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("reviewNote")
    }

    private var headline: Text {
        switch ViewRules.reviewReason(of: task) {
        case .titleChanged:
            let others = automaticFields - 1
            switch others {
            case ..<1: return Text("Title reworded.")
            case 1: return Text("Title reworded, one field set.")
            default: return Text("Title reworded, \(others) fields set.")
            }
        case .sortedByAI:
            switch automaticFields {
            case ..<1: return Text("Sorted.")
            case 1: return Text("One field set.")
            default: return Text("\(automaticFields) fields set.")
            }
        case .titleNotChecked: return Text("Title not checked")
        case .notSortedYet: return Text("Not sorted yet")
        }
    }

    /// No hint for a task the rules sorted and nobody else will: the model is out of the product path
    /// (ADR-22, #982), so nothing happens "by itself" any more.
    private var hint: Text? {
        switch ViewRules.reviewReason(of: task) {
        case .titleChanged, .sortedByAI: Text("Check the tinted values, then “Looks right”.")
        case .titleNotChecked: Text("Does it fit? Otherwise tap it and change it.")
        case .notSortedYet: nil
        }
    }
}
