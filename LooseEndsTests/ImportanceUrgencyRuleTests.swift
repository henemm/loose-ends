import Foundation
import Testing
@testable import LooseEnds

/// Der Regelschritt für Wichtigkeit und Dringlichkeit (#117, Teil von #112 Alternative 1): ersetzt
/// den Modellaufruf durch Textmuster, nach demselben Muster wie `DueDateRule` (#95). Issue #111 hat
/// gezeigt, dass die bisherige FocusBlox-„Wahrheit" für diese Felder ohnehin nur Fallback-Standard-
/// werte war — kein Grund, hier selbst einen Default einzuführen: Kein Treffer bleibt `nil`.
/// Zwei unabhängige Funktionen statt eines Tripels, weil Wichtigkeit und Dringlichkeit laut
/// Datenmodell orthogonale Felder sind.
@Suite("Regelschritt: Wichtigkeit und Dringlichkeit")
struct ImportanceUrgencyRuleTests {
    @Test("Wichtigkeits-Treffer je Kategorie (AC-1)")
    func importanceHitsPerCategory() throws {
        let cases: [(sentence: String, category: String)] = [
            ("250 Euro an den Verein überweisen", "money"),
            ("Die Steuererklärung fürs Finanzamt abgeben", "official"),
            ("Er wartet auf meine Antwort", "peopleWaiting"),
        ]

        var reasons: [String] = []
        for (sentence, category) in cases {
            let match = try #require(ImportanceUrgencyRule.matchImportance(in: sentence), "\(category): \(sentence)")
            #expect(match.value == .high, "\(category): \(sentence)")
            #expect(match.confidence == 1.0, "\(category): \(sentence)")
            #expect(!match.reason.isEmpty, "\(category): \(sentence)")
            reasons.append(match.reason)
        }

        #expect(Set(reasons).count == cases.count, "jede Kategorie begründet sich anders")
    }

    @Test("Dringlichkeits-Treffer je Kategorie (AC-2)")
    func urgencyHitsPerCategory() throws {
        let cases: [(sentence: String, category: String)] = [
            ("Dringend das Formular ausfüllen", "immediacy"),
            ("Die Frist läuft morgen ab", "deadline"),
        ]

        var reasons: [String] = []
        for (sentence, category) in cases {
            let match = try #require(ImportanceUrgencyRule.matchUrgency(in: sentence), "\(category): \(sentence)")
            #expect(match.value == .high, "\(category): \(sentence)")
            #expect(match.confidence == 1.0, "\(category): \(sentence)")
            #expect(!match.reason.isEmpty, "\(category): \(sentence)")
            reasons.append(match.reason)
        }

        #expect(Set(reasons).count == cases.count, "jede Kategorie begründet sich anders")
    }

    /// Kein Treffer heißt `nil`, nicht „.low" oder „.medium" — genau die Eigenschaft, die #111 an
    /// der alten FocusBlox-„Wahrheit" fehlte.
    @Test("Kein Treffer bleibt nil, kein Default (AC-3)")
    func noHitStaysNil() {
        #expect(ImportanceUrgencyRule.matchImportance(in: "Blumen gießen") == nil)
        #expect(ImportanceUrgencyRule.matchUrgency(in: "Blumen gießen") == nil)
    }

    /// „Dringend, aber unwichtig" ist valide (`ViewRules.byUrgencyThenImportance`) — kein Feld wird
    /// aus dem Treffer des anderen abgeleitet.
    @Test("Wichtigkeit und Dringlichkeit sind unabhängig (AC-4)")
    func fieldsAreIndependent() {
        #expect(ImportanceUrgencyRule.matchUrgency(in: "Sofort zurückrufen")?.value == .high)
        #expect(ImportanceUrgencyRule.matchImportance(in: "Sofort zurückrufen") == nil)

        #expect(ImportanceUrgencyRule.matchImportance(in: "250 Euro an den Verein überweisen")?.value == .high)
        #expect(ImportanceUrgencyRule.matchUrgency(in: "250 Euro an den Verein überweisen") == nil)
    }

    /// Der Begründungssatz erscheint im Aufgaben-Detail und im Feld-Editor über `revision.reason`.
    /// Anders als bei #98 (nachträglich übersetzt) ist die deutsche Übersetzung von Anfang an Teil
    /// dieser Spec (AC-8). Testaufbau wie `DueDateRuleTests.reasonsAreTranslatedToGerman()`.
    @Test("Alle fünf Begründungssätze sind im deutschen Bundle übersetzt (AC-8)")
    func reasonsAreTranslatedToGerman() throws {
        let path = try #require(Bundle.main.path(forResource: "de", ofType: "lproj"))
        let germanBundle = try #require(Bundle(path: path))

        let keys = [
            "From an amount of money in the note.",
            "From official or legal language in the note.",
            "From someone waiting for this in the note.",
            "From an urgency word in the note.",
            "From a deadline reference in the note.",
        ]

        for key in keys {
            let translated = germanBundle.localizedString(forKey: key, value: key, table: nil)
            #expect(translated != key, "\(key)")
        }
    }

    /// Muss ohne Modell und ohne Plattform-Klammer kompilieren: `Shared/` geht in App, Watch,
    /// Widgets und Share-Erweiterung, und `FoundationModels` gibt es auf der Watch nicht.
    @Test("Der Regelschritt liegt im Produktmodul")
    func ruleLivesInProductModule() {
        #expect(String(reflecting: ImportanceUrgencyRule.self).hasPrefix("LooseEnds."))
    }
}

/// AC-7: Das Modellschema verliert die sechs importance/urgency-Eigenschaften. Nur dort geprüft,
/// wo `ModelEnrichment` überhaupt existiert (`FoundationModelsEnricher.swift` ist selbst auf
/// `#if canImport(FoundationModels) && !os(watchOS)` beschränkt).
#if canImport(FoundationModels) && !os(watchOS)
@Suite("ModelEnrichment ohne Wichtigkeit/Dringlichkeit (AC-7)")
struct ModelEnrichmentSchemaTests {
    @Test("Das Schema trägt keine importance/urgency-Eigenschaften mehr")
    func schemaHasNoImportanceOrUrgencyProperties() {
        let sample = ModelEnrichment(
            title: "x", titleConfidence: 1, titleReason: "x",
            duration: "x", durationConfidence: 1, durationReason: "x",
            energy: "x", energyConfidence: 1, energyReason: "x",
            contexts: [], contextsConfidence: 1, contextsReason: "x",
            people: [], peopleConfidence: 1, peopleReason: "x",
            project: "x", projectConfidence: 1, projectReason: "x"
        )
        let labels = Set(Mirror(reflecting: sample).children.compactMap(\.label))

        let removed = [
            "importance", "importanceConfidence", "importanceReason",
            "urgency", "urgencyConfidence", "urgencyReason",
        ]
        for label in removed {
            #expect(!labels.contains(label), "\(label)")
        }
    }
}
#endif
