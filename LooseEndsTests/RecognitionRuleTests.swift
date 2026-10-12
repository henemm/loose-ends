import Foundation
import Testing
@testable import LooseEnds

/// Die Wiedererkennung bekannter Rohtexte (#136): kein Lernen, sondern ein Textabgleich.
///
/// Der Mechanismus ist **Gleichheit der normalisierten Wortmenge**, nicht die im Ticket zunächst
/// vorgesehene Jaccard-Schwelle 0,34. Nachgerechnet auf den 287 echten Aufgaben trifft Gleichheit
/// bei Kontexten und Dauer je 100 % exakt, die Schwelle 100 %/97,2 %. Die Schwelle kauft über den
/// ganzen Bestand elf Fälle dazu, davon fünf falsche Dauern („Termin für Reifenwechsel machen"
/// gegen „Termin für Hautkrebs-Früherkennungsuntersuchung machen"), und sie schneidet sie nicht
/// weg: die Dauer-Fehltreffer liegen bei 0,5 und 0,667, also über 0,34. Ein falsch gesetzter
/// Kontext ist für den Nutzer unsichtbar — deshalb entscheidet die Regel zugunsten der Strenge.
///
/// Reine Regel nach dem Vorbild `DueDateRule` (#95) und `ImportanceUrgencyRule` (#117): ein `enum`,
/// kein Zustand, kein SwiftData. Die Vergleichsmenge reicht der Coordinator herein.
@Suite("Wiedererkennung: Regel (#136)")
struct RecognitionRuleTests {

    private func candidate(
        _ rawText: String,
        id: UUID = UUID(),
        duration: DurationBucket? = nil,
        durationSource: FieldSource? = .user,
        contexts: [String] = [],
        contextsSource: FieldSource? = .user
    ) -> RecognitionRule.Candidate {
        RecognitionRule.Candidate(
            id: id,
            rawText: rawText,
            duration: duration,
            durationSourceRaw: durationSource?.rawValue,
            contextNames: contexts,
            contextsSourceRaw: contextsSource?.rawValue
        )
    }

    @Test("Gleiche Wortmenge übernimmt Dauer und Kontexte mit Konfidenz 1.0 (AC-1)")
    func identicalWordSetAdoptsBothFields() throws {
        let source = candidate("Rasen mähen", duration: .minutes30, contexts: ["Garten"])
        let match = try #require(RecognitionRule.match(rawText: "Rasen mähen", in: [source]))

        let duration = try #require(match.duration)
        #expect(duration.sourceID == source.id)
        #expect(duration.guess.value == .minutes30)
        #expect(duration.guess.confidence == RecognitionRule.confidence)
        #expect(duration.guess.confidence == 1.0)
        #expect(!duration.guess.reason.isEmpty)

        let contexts = try #require(match.contexts)
        #expect(contexts.sourceID == source.id)
        #expect(contexts.guess.value == ["Garten"])
        #expect(contexts.guess.confidence == 1.0)
    }

    @Test("Ein anderer Text liefert nichts — kein Standardwert (AC-2)")
    func differentTextYieldsNothing() {
        let source = candidate("Zettel sortieren", duration: .minutes15, contexts: ["Büro"])
        #expect(RecognitionRule.match(rawText: "Rasen mähen", in: [source]) == nil)
    }

    /// Das Produkt verarbeitet diktierten Rohtext (#82/#88): Satzzeichen, Groß-/Kleinschreibung und
    /// Wortstellung dürfen eine Wiedererkennung nicht verhindern, ein anderes Wort schon.
    @Test("Groß-/Kleinschreibung, Satzzeichen, Wortstellung und Umlaute sind egal (AC-3)")
    func normalisationIsIgnored() throws {
        let source = candidate("LinkedIn Nachrichten beantworten.", duration: .minutes15)
        let variants = [
            "linkedin nachrichten beantworten",
            "Nachrichten LinkedIn beantworten!",
            "  LINKEDIN   nachrichten,beantworten  ",
        ]
        for variant in variants {
            let match = try #require(RecognitionRule.match(rawText: variant, in: [source]), "\(variant)")
            #expect(match.duration?.guess.value == .minutes15, "\(variant)")
        }
    }

    /// Kein Vier-Zeichen-Filter. Er existiert in `LeaveOneOut.similarityWords` nur, weil deutsche
    /// Funktionswörter eine *Ähnlichkeitssuche* verrauschen würden; bei einem Gleichheitsvergleich
    /// ist er reiner Nachteil. Beide Paare nennt der Messbericht als Grenze.
    @Test("Kurze Wörter zählen mit — keine Falschverschmelzung (AC-4)")
    func shortWordsAreNotDropped() {
        let bath = candidate("Bad holen", duration: .minutes30)
        #expect(RecognitionRule.match(rawText: "Tee holen", in: [bath]) == nil)

        let sixty = candidate("60 Minuten Sport", duration: .hour1)
        #expect(RecognitionRule.match(rawText: "30 Minuten Sport", in: [sixty]) == nil)
    }

    /// Energie bleibt manuell (#112): Nachbarn schlagen dort die Konstante auf keiner Lesart
    /// (69,9 % gegen 77,3 %). Die Regel kann das Feld nicht setzen, weil es sie nicht kennt —
    /// strukturell, nicht durch eine Zeile, die jemand später wieder entfernt.
    @Test("Weder Treffer noch Kandidat kennen Energie (AC-5)")
    func energyIsStructurallyAbsent() throws {
        let source = candidate("Klavier spielen", duration: .hour1, contexts: ["Zuhause"])
        let match = try #require(RecognitionRule.match(rawText: "Klavier spielen", in: [source]))

        let matchLabels = Mirror(reflecting: match).children.compactMap(\.label)
        #expect(!matchLabels.contains { $0.lowercased().contains("energy") },
                "RecognitionRule.Match hat kein Energiefeld: \(matchLabels)")

        let candidateLabels = Mirror(reflecting: source).children.compactMap(\.label)
        #expect(!candidateLabels.contains { $0.lowercased().contains("energy") },
                "RecognitionRule.Candidate hat kein Energiefeld: \(candidateLabels)")
    }

    /// ADR-5: „Korrekturen des Nutzers bleiben Beispiele erster Klasse." Seit #244 sind sie die
    /// einzige Quelle — je Feld einzeln, weil Dauer und Kontexte von verschiedenen Nachbarn stammen
    /// dürfen.
    @Test("Nur nutzergesetzte Werte sind Quelle, je Feld einzeln (AC-6, #244)")
    func userSetValuesWin() throws {
        let byAI = candidate("Steuer sortieren", duration: .minutes15, durationSource: .ai,
                             contexts: ["Büro"], contextsSource: .user)
        let byUser = candidate("Steuer sortieren", duration: .hours2plus, durationSource: .user,
                               contexts: ["Garten"], contextsSource: .rule)

        for pool in [[byAI, byUser], [byUser, byAI]] {
            let match = try #require(RecognitionRule.match(rawText: "Steuer sortieren", in: pool))
            #expect(match.duration?.guess.value == .hours2plus, "Dauer: Nutzerwert gewinnt")
            #expect(match.duration?.sourceID == byUser.id)
            #expect(match.contexts?.guess.value == ["Büro"], "Kontexte: Nutzerwert gewinnt")
            #expect(match.contexts?.sourceID == byAI.id)
        }
    }

    /// Ohne Tiebreaker hinge das Ergebnis an der Reihenfolge des SwiftData-Fetch — derselbe Text
    /// ergäbe je nach Lauf eine andere Dauer.
    @Test("Bei gleichrangigen Treffern entscheidet die id, nicht die Pool-Reihenfolge (AC-6)")
    func tiesBreakByIdNotByPoolOrder() throws {
        let lower = candidate("Fenster putzen", id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                              duration: .minutes15, durationSource: .user)
        let higher = candidate("Fenster putzen", id: UUID(uuidString: "FFFFFFFF-0000-0000-0000-000000000001")!,
                               duration: .hour1, durationSource: .user)

        for pool in [[lower, higher], [higher, lower]] {
            let match = try #require(RecognitionRule.match(rawText: "Fenster putzen", in: pool))
            #expect(match.duration?.sourceID == lower.id)
            #expect(match.duration?.guess.value == .minutes15)
        }
    }

    /// #215: Henning erfasste „Morgen wichtig Steuerbescheid prüfen“ zweimal. Der zweite Lauf übernahm
    /// den geratenen Kontext „Haus“ des ersten mit dem Regelzeichen » «.
    @Test("Ein von der KI geratener Wert ist keine Quelle (#215)")
    func aiGuessIsNoSource() {
        let guessed = candidate("Steuerbescheid prüfen", duration: .minutes15, durationSource: .ai,
                                contexts: ["Haus"], contextsSource: .ai)
        #expect(RecognitionRule.match(rawText: "Steuerbescheid prüfen", in: [guessed]) == nil)
    }

    /// #244: Dieselbe Vermutung kam beim dritten Mal trotzdem — eine frühere Wiedererkennung hatte sie
    /// schon übernommen und mit Herkunft `rule` gespeichert. Ein Regelwert ist deshalb keine Quelle
    /// (ein Wortregel-Treffer braucht keine Kopie, dieselben Wörter treffen dieselbe Regel), und ein
    /// Wert ohne Herkunft auch nicht.
    @Test("Ein Regelwert und ein Wert ohne Herkunft sind keine Quelle (#244)")
    func ruleOrUnknownValueIsNoSource() {
        let copied = candidate("Morgen wichtig Steuerbescheid prüfen", duration: .minutes30, durationSource: .rule,
                               contexts: ["Haus"], contextsSource: .rule)
        let unknown = candidate("Morgen wichtig Steuerbescheid prüfen", duration: .hour1, durationSource: nil,
                                contexts: ["Büro"], contextsSource: nil)
        #expect(RecognitionRule.match(rawText: "Morgen wichtig Steuerbescheid prüfen", in: [copied, unknown]) == nil)

        let byUser = candidate("Morgen wichtig Steuerbescheid prüfen", contexts: ["Büro"])
        let match = RecognitionRule.match(rawText: "Morgen wichtig Steuerbescheid prüfen", in: [copied, byUser, unknown])
        #expect(match?.contexts?.guess.value == ["Büro"])
        #expect(match?.duration == nil, "der Nutzer hat keine Dauer gesetzt")
    }

    @Test("Ein Kandidat ohne gesetztes Feld liefert für dieses Feld nichts")
    func candidateWithoutFieldYieldsNothingForIt() throws {
        let source = candidate("Müll rausbringen", duration: nil, contexts: ["Zuhause"])
        let match = try #require(RecognitionRule.match(rawText: "Müll rausbringen", in: [source]))
        #expect(match.duration == nil)
        #expect(match.contexts?.guess.value == ["Zuhause"])
    }

    @Test("Ein Treffer ohne jedes gesetzte Feld ist kein Treffer")
    func matchWithoutAnyFieldIsNil() {
        let source = candidate("Müll rausbringen")
        #expect(RecognitionRule.match(rawText: "Müll rausbringen", in: [source]) == nil)
    }

    @Test("Leerer Pool und wortloser Rohtext stürzen nicht ab und treffen nichts")
    func emptyPoolAndWordlessTextAreSafe() {
        #expect(RecognitionRule.match(rawText: "Rasen mähen", in: []) == nil)

        let wordless = candidate("!!! ???", duration: .minutes5)
        #expect(RecognitionRule.match(rawText: "…", in: [wordless]) == nil,
                "zwei wortlose Texte sind nicht dieselbe Aufgabe")
    }

    /// Nachgeschlagen wird der **englische Schlüssel**, nicht der zur Laufzeit gelieferte Satz: der
    /// Testläufer spricht Deutsch (`AppleLanguages = de-DE` im Simulator), `String(localized:)` gibt
    /// dort schon die Übersetzung zurück, und die als Schlüssel nachzuschlagen schlägt immer fehl —
    /// unabhängig von der Implementierung. Die zweite Erwartung bindet den Laufzeitsatz an genau
    /// diesen Schlüssel, damit der Test nicht an einem beliebigen Satz vorbeiläuft. Muster wie
    /// `ImportanceUrgencyRuleTests.reasonsAreTranslatedToGerman()` (AC-8 dort).
    @Test("Der Begründungssatz ist ins Deutsche übersetzt (AC-11)")
    func reasonIsTranslatedToGerman() throws {
        let source = candidate("Rasen mähen", duration: .minutes30)
        let match = try #require(RecognitionRule.match(rawText: "Rasen mähen", in: [source]))
        let reason = try #require(match.duration).guess.reason

        let key = "From a raw text captured before, word for word."
        let german = try #require(Bundle.main.path(forResource: "de", ofType: "lproj"))
        let bundle = try #require(Bundle(path: german))
        let translated = bundle.localizedString(forKey: key, value: key, table: nil)
        #expect(translated != key, "kein Rückfall auf den englischen Schlüsseltext: \(key)")
        #expect(reason == key || reason == translated,
                "die Regel nennt genau diesen Satz, englisch oder deutsch: \(reason)")
    }
}

/// Der geteilte Tokenizer (#136): Messung und Produkt zerlegen denselben Text gleich. Vorher lag er
/// als `TitleCheck.normalized`/`TitleCheck.words(in:)` in `Measurement/`, also außerhalb des
/// Produktpfads — ein zweiter Tokenizer im Produkt hätte bedeutet, dass die Messung etwas anderes
/// misst als die App tut.
@Suite("Geteilter Tokenizer (#136)")
struct RawTextWordsTests {

    @Test("Faltet Groß-/Kleinschreibung und Diakritika, erhält Bindestriche")
    func normalisesAndKeepsHyphens() {
        #expect(RawTextWords.normalized("Özdemir") == RawTextWords.normalized("özdemir"))
        #expect(RawTextWords.normalized("Muell") != RawTextWords.normalized("Müll"),
                "eine echte Textänderung bleibt eine")
        #expect(RawTextWords.words(in: "Mutter-Kind-Kur beantragen") == ["Mutter-Kind-Kur", "beantragen"])
        #expect(RawTextWords.words(in: "30 Minuten, Sport!") == ["30", "Minuten", "Sport"])
    }

    /// AC-10, erster Nachweis: `LeaveOneOut.similarityWords` ist nichts anderes als der geteilte
    /// Tokenizer plus Längenfilter. Driftet eine der beiden Zerlegungen ab, schlägt das hier fehl.
    @Test("Die Messung baut auf demselben Tokenizer auf (AC-10)")
    func measurementUsesTheSharedTokenizer() {
        let texts = [
            "Mutter-Kind-Kur beantragen, 30 Minuten",
            "LinkedIn Nachrichten beantworten.",
            "Özdemir anrufen wegen Straße",
        ]
        for text in texts {
            let expected = Set(RawTextWords.words(in: text).map(RawTextWords.normalized).filter { $0.count >= 4 })
            #expect(LeaveOneOut.similarityWords(text) == expected, "\(text)")
        }
    }

    /// AC-10, zweiter Nachweis: strukturell. Solange `Measurement/Corpus.swift` eigene Fassungen
    /// dieser beiden Funktionen deklariert, kann jemand sie ändern, ohne dass das Produkt es merkt.
    @Test("Measurement/Corpus.swift deklariert keinen eigenen Tokenizer mehr (AC-10)")
    func measurementDeclaresNoOwnTokenizer() throws {
        let corpusFile = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Measurement/Corpus.swift")
        let source = try String(contentsOf: corpusFile, encoding: .utf8)

        #expect(!source.contains("static func normalized("),
                "TitleCheck.normalized gehört nach Shared/Services/RawTextWords.swift")
        #expect(!source.contains("static func words(in"),
                "TitleCheck.words(in:) gehört nach Shared/Services/RawTextWords.swift")
    }
}

private let recognitionCorpusURL = MeasurementData.focusBloxCorpus

/// Die Messung der Regel gegen die 287 echten Aufgaben (AC-12). Eigene Suite und per
/// `.enabled(if:)` gegattert, weil `focusblox-corpus.json` persönliche, gitignorierte Daten sind und
/// in CI nie existieren — **„grün ohne Korpus" heißt „Messung übersprungen", nicht „bestanden".** Seit
/// #149 sagt das der Lauf selbst: Der Grund steht am Überspringen, und `sim.sh unit` und die CI nennen
/// danach jede Messstrecke, die nicht gemessen hat.
///
/// Beide Lesarten laufen, nicht nur die günstigere: der volle Pool zeigt, was die Regel im Alltag
/// leistet, der entduplizierte zeigt, dass es Wiedererkennung ist und keine Ähnlichkeitsaussage für
/// neu formulierten Text. Ohne die zweite Zahl liest die Messung halb.
///
/// **Grenze, die zu jeder dieser Zahlen gehört:** Sie gelten für gepflegte Titel aus dem
/// FocusBlox-Export (`scripts/export-focusblox-corpus.swift` setzt `rawText: title`), nicht für
/// diktierten Rohtext (#82/#88). Wie gut die Regel auf Diktat trifft, ist mit diesem Korpus nicht
/// messbar.
@Suite(.enabled(if: MeasurementData.exists(recognitionCorpusURL), MeasurementData.corpusMissing))
struct RecognitionRuleCorpusTests {

    private func pool(from entries: [Corpus.Entry]) -> [RecognitionRule.Candidate] {
        entries.map { entry in
            RecognitionRule.Candidate(
                id: UUID(uuidString: entry.id) ?? UUID(),
                rawText: entry.text,
                duration: entry.durationTruth.flatMap(DurationBucket.init(rawValue:)),
                durationSourceRaw: FieldSource.user.rawValue,
                contextNames: entry.contextsTruth ?? [],
                contextsSourceRaw: FieldSource.user.rawValue
            )
        }
    }

    /// Ein Vertreter je textgleicher Gruppe, erster in Korpus-Reihenfolge — wie
    /// `RuleLeaveOneOutReportTests.deduplicated(_:)`, damit beide Berichte dieselbe Gegenprobe meinen.
    private func deduplicated(_ entries: [Corpus.Entry]) -> [Corpus.Entry] {
        var seen: Set<String> = []
        return entries.filter {
            seen.insert($0.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()).inserted
        }
    }

    @Test("Voller Pool: 61 von 104 Kontext- und 169 von 276 Dauer-Aufgaben, je 100 % richtig (AC-12)")
    func fullPoolReproducesTheMeasuredNumbers() throws {
        let entries = try JSONDecoder().decode([Corpus.Entry].self,
                                               from: Data(contentsOf: recognitionCorpusURL))
        let contextEntries = entries.filter { !($0.contextsTruth ?? []).isEmpty }
        let durationEntries = entries.filter { $0.durationTruth != nil }
        #expect(contextEntries.count == 104)
        #expect(durationEntries.count == 276)

        var contextHits = 0, contextCorrect = 0
        for entry in contextEntries {
            let others = pool(from: contextEntries.filter { $0.id != entry.id })
            guard let contexts = RecognitionRule.match(rawText: entry.text, in: others)?.contexts else { continue }
            contextHits += 1
            if Set(contexts.guess.value.map { $0.lowercased() })
                == Set((entry.contextsTruth ?? []).map { $0.lowercased() }) { contextCorrect += 1 }
        }
        #expect(contextHits == 61)
        #expect(contextCorrect == 61, "100 % der Treffer richtig")

        var durationHits = 0, durationCorrect = 0
        for entry in durationEntries {
            let others = pool(from: durationEntries.filter { $0.id != entry.id })
            guard let duration = RecognitionRule.match(rawText: entry.text, in: others)?.duration else { continue }
            durationHits += 1
            if duration.guess.value.rawValue == entry.durationTruth { durationCorrect += 1 }
        }
        #expect(durationHits == 169)
        #expect(durationCorrect == 169, "100 % der Treffer richtig")
    }

    @Test("Entduplizierter Pool: praktisch kein Treffer — es ist Wiedererkennung, keine Ähnlichkeit (AC-12)")
    func deduplicatedPoolShowsItIsRecognitionNotSimilarity() throws {
        let entries = try JSONDecoder().decode([Corpus.Entry].self,
                                               from: Data(contentsOf: recognitionCorpusURL))
        let contextEntries = deduplicated(entries.filter { !($0.contextsTruth ?? []).isEmpty })
        let durationEntries = deduplicated(entries.filter { $0.durationTruth != nil })
        #expect(contextEntries.count == 50)
        #expect(durationEntries.count == 115)

        let contextHits = contextEntries.filter { entry in
            RecognitionRule.match(rawText: entry.text,
                                  in: pool(from: contextEntries.filter { $0.id != entry.id }))?.contexts != nil
        }.count
        let durationHits = durationEntries.filter { entry in
            RecognitionRule.match(rawText: entry.text,
                                  in: pool(from: durationEntries.filter { $0.id != entry.id }))?.duration != nil
        }.count

        #expect(contextHits == 0, "entdupliziert bleibt kein wortgleiches Paar übrig")
        #expect(durationHits == 0, "entdupliziert bleibt kein wortgleiches Paar übrig")
    }
}
