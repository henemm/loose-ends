import Testing
import UIKit
@testable import LooseEnds

/// Which sign stands with which field (#344): one source for the list row and the detail's register line.
@Suite("Field glyphs") struct FieldGlyphTests {
    @Test("Importance is a ladder of exclamation marks")
    func importanceLadder() {
        #expect(FieldGlyph.importance(.low) == "exclamationmark")
        #expect(FieldGlyph.importance(.medium) == "exclamationmark.2")
        #expect(FieldGlyph.importance(.high) == "exclamationmark.3")
    }

    @Test("Urgency, due, duration and project each have their sign")
    func fieldSigns() {
        #expect(FieldGlyph.symbol(for: .urgency) == "flame")
        #expect(FieldGlyph.symbol(for: .dueDate) == "calendar")
        #expect(FieldGlyph.symbol(for: .duration) == "clock")
        #expect(FieldGlyph.symbol(for: .project) == "folder")
    }

    @Test("Importance has no single sign: the ladder carries it")
    func importanceHasNoFlatSign() {
        #expect(FieldGlyph.symbol(for: .importance) == nil)
    }

    @Test("Fields without a sign give nil")
    func fieldsWithoutSign() {
        for field in [RevisedField.title, .energy, .contexts, .people, .blockedBy, .repeatRule, .place] {
            #expect(FieldGlyph.symbol(for: field) == nil, "\(field) should have no sign")
        }
    }

    @Test("Every name is a system symbol, and the old flag and bolt are gone")
    func namesExist() {
        let names = Importance.allCases.map(FieldGlyph.importance) + RevisedField.allCases.compactMap(FieldGlyph.symbol(for:))
        #expect(!names.isEmpty)
        for name in names {
            #expect(UIImage(systemName: name) != nil, "\(name) is no SF Symbol")
            #expect(name != "flag.fill" && name != "bolt.fill")
        }
    }
}
