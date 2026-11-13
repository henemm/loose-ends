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

    /// #214: Das ausdrückliche Wort „wichtig" setzt die Wichtigkeit, vor allen indirekten Signalen.
    /// „Steuerbescheid" trifft seit #864 auch das Amtssignal (Zusammensetzung); das Wort „wichtig" geht
    /// ihm trotzdem vor, die Begründung bleibt die des ausdrücklichen Wortes.
    @Test("„wichtig“ setzt hohe Wichtigkeit, mit eigener Begründung (#214)")
    func explicitWordSetsImportance() throws {
        let match = try #require(ImportanceUrgencyRule.matchImportance(in: "Morgen wichtig Steuerbescheid prüfen"))
        #expect(match.value == .high)
        #expect(match.confidence == 1.0)
        #expect(match.reason == String(localized: "From the word “important” in the note."))

        for sentence in ["Sehr wichtig: Anna anrufen", "Wichtige Unterlagen kopieren", "Important: call the bank",
                         "Ein wichtiges Gespräch vorbereiten"] {
            #expect(ImportanceUrgencyRule.matchImportance(in: sentence)?.value == .high, "\(sentence)")
        }
    }

    @Test("Das ausdrückliche Wort geht den indirekten Signalen vor (#214)")
    func explicitWordComesFirst() {
        let match = ImportanceUrgencyRule.matchImportance(in: "Rechnung bezahlen, wichtig")
        #expect(match?.reason == String(localized: "From the word “important” in the note."))
    }

    @Test("Kein Fehltreffer bei „unwichtig“ und verneintem „wichtig“ (#214)",
          arguments: ["Unwichtig: Keller aufräumen", "Nicht wichtig, Keller aufräumen", "Keller aufräumen, nicht so wichtig",
                      "Keller aufräumen, ist nicht sehr wichtig", "Not important: tidy the cellar", "Tidy the cellar, not very important"])
    func negatedWordIsNoHit(sentence: String) {
        #expect(ImportanceUrgencyRule.matchImportance(in: sentence) == nil)
        #expect(ImportanceUrgencyRule.importanceTrigger(in: sentence) == nil)
    }

    @Test("Eine Verneinung zwei Wörter vorher ohne Verstärker zählt nicht (#214)")
    func distantNegationDoesNotCount() {
        #expect(ImportanceUrgencyRule.matchImportance(in: "Nicht vergessen: wichtig Steuer prüfen")?.value == .high)
    }

    @Test("Ein verneintes und ein bejahtes „wichtig“: das bejahte zählt (#214)")
    func laterUnnegatedWordCounts() throws {
        let text = "Nicht wichtig: Keller. Wichtig: Steuer"
        let range = try #require(ImportanceUrgencyRule.importanceTrigger(in: text))
        #expect(text[range] == "Wichtig")
        #expect(range.lowerBound > text.startIndex)
    }

    @Test("Verneinte Dringlichkeit setzt nichts (#220)",
          arguments: ["Keller aufräumen, nicht dringend", "Nicht so dringend: Keller aufräumen",
                      "Tidy the cellar, not urgent", "Nicht sofort, erst nächste Woche"])
    func negatedUrgencyIsNoHit(sentence: String) {
        #expect(ImportanceUrgencyRule.matchUrgency(in: sentence) == nil)
        #expect(ImportanceUrgencyRule.urgencyTrigger(in: sentence) == nil)
    }

    @Test("Eine Frist bleibt ein Treffer, auch neben verneinter Eile (#220)")
    func deadlineStaysAHit() {
        #expect(ImportanceUrgencyRule.matchUrgency(in: "Nicht dringend, aber Frist beachten")?.value == .high)
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
    @Test("Alle sechs Begründungssätze sind im deutschen Bundle übersetzt (AC-8, #214)")
    func reasonsAreTranslatedToGerman() throws {
        let path = try #require(Bundle.main.path(forResource: "de", ofType: "lproj"))
        let germanBundle = try #require(Bundle(path: path))

        let keys = [
            "From the word “important” in the note.",
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

    // MARK: - #864 Zusammensetzungen mit Amtswörtern

    private var officialReason: String { String(localized: "From official or legal language in the note.") }

    @Test("Amtswort-Stamm vorn setzt hohe Wichtigkeit (#864 AC-1)", arguments: [
        "Steuerbescheid prüfen", "Steuernachzahlung überweisen", "Steuerberater anrufen",
        "Steuerbescheide ablegen", "Umsatzsteuer melden", "Amtsgerichts Post lesen",
    ])
    func compoundStemsSetImportance(sentence: String) throws {
        let match = try #require(ImportanceUrgencyRule.matchImportance(in: sentence), "\(sentence)")
        #expect(match.value == .high, "\(sentence)")
        #expect(match.confidence == 1.0, "\(sentence)")
        #expect(match.reason == officialReason, "\(sentence)")
    }

    @Test("Amtswort hinten setzt hohe Wichtigkeit (#864 AC-2)", arguments: [
        "Mietvertrag kündigen", "Scheidungsanwalt anrufen", "Waffenbehörde fragen", "Staatsanwalt",
    ])
    func compoundHeadsSetImportance(sentence: String) throws {
        let match = try #require(ImportanceUrgencyRule.matchImportance(in: sentence), "\(sentence)")
        #expect(match.value == .high, "\(sentence)")
        #expect(match.reason == officialReason, "\(sentence)")
    }

    @Test("Nur ähnlich aussehende Wörter treffen nicht (#864 AC-3)", arguments: [
        "Steuerrad reparieren", "Steuerung einbauen", "Steuerknüppel kaufen", "Lenksteuer",
        "Gesamt zählen", "insgesamt drei", "Hauptgericht kochen", "Beamtenrecht lesen",
        "Vertragsnummer notieren",
    ])
    func lookAlikesDoNotSetImportance(sentence: String) {
        #expect(ImportanceUrgencyRule.matchImportance(in: sentence) == nil, "\(sentence)")
    }

    @Test("Bisherige Amtstreffer bleiben (#864 AC-4)", arguments: [
        "Finanzamt anrufen", "Steuererklärung", "Amt", "Vertrag", "Check the tax notice today",
    ])
    func formerOfficialHitsStay(sentence: String) throws {
        let match = try #require(ImportanceUrgencyRule.matchImportance(in: sentence), "\(sentence)")
        #expect(match.value == .high, "\(sentence)")
        #expect(match.reason == officialReason, "\(sentence)")
    }

    @Test("Steuerbescheid trifft ohne „wichtig“ mit der Amtsbegründung (#864 AC-4)")
    func steuerbescheidNeedsNoImportantWord() throws {
        let match = try #require(ImportanceUrgencyRule.matchImportance(in: "Steuerbescheid prüfen"))
        #expect(match.reason == officialReason)
    }

    @Test("Die Spanne deckt das ganze Kompositum ab (#864 AC-5)")
    func triggerCoversWholeCompound() throws {
        for (sentence, word) in [("Steuerbescheide ablegen", "Steuerbescheide"), ("Mietvertrag kündigen", "Mietvertrag")] {
            let range = try #require(ImportanceUrgencyRule.importanceTrigger(in: sentence), "\(sentence)")
            #expect(String(sentence[range]) == word, "\(sentence)")
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
            contexts: [], contextsConfidence: 1, contextsReason: "x",
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
