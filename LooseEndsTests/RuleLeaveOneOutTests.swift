import Foundation
import Testing
@testable import LooseEnds

/// The rule-only leave-one-out test for Annahme B1 (Spike #69, Issue #131): for every task, find
/// the k most similar *other* tasks by word overlap, let their values vote, and check the answer
/// against the truth — no model, no embedding, no device. The question is whether that beats the
/// constant ("always answer the most frequent class"), because the model does not: duration 51 %
/// against a 51,1 % constant, energy 25 % against 77,3 %.
///
/// Two suites on purpose. The logic tests below must run in CI, the report suite must not: it
/// needs `docs/reference/focusblox-corpus.json`, which is personal, gitignored data
/// ([[feedback-phone-is-not-a-test-bench]]). `.enabled(if:)` gates a whole suite, never a single
/// test, so gating them together would silently drop the logic tests from every CI run.
private func repoFile(_ relativePath: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent(relativePath)
}
private let focusBloxTruthURL = repoFile("docs/reference/focusblox-corpus.json")
private let leaveOneOutReportURL = repoFile("docs/reference/retrieval-leave-one-out-rules.md")

private func percent(_ value: Double) -> String {
    String(format: "%.1f %%", value * 100)
}

/// `Corpus.Entry` is `Decodable` only — it has no memberwise initialiser, and giving it one just
/// for the tests would widen a type the measurement code shares. Building the cases through JSON
/// keeps `LeaveOneOut` bound to the real entry type instead of a parallel test double.
private func makeEntry(
    id: String,
    text: String,
    contexts: [String]? = nil,
    duration: String? = nil,
    energy: String? = nil
) throws -> Corpus.Entry {
    var object: [String: Any] = ["id": id, "lang": "de", "text": text]
    if let contexts { object["contextsTruth"] = contexts }
    if let duration { object["durationTruth"] = duration }
    if let energy { object["energyTruth"] = energy }
    let data = try JSONSerialization.data(withJSONObject: object)
    return try JSONDecoder().decode(Corpus.Entry.self, from: data)
}

@Suite("Regel-Auslass-Test: Logik (Spike #69, #131)")
struct RuleLeaveOneOutTests {

    @Test("Die Zielaufgabe ist nie ihr eigener Nachbar (AC-1)")
    func targetIsNeverItsOwnNeighbor() throws {
        let target = try makeEntry(id: "t", text: "Rasen mähen heute")
        let other = try makeEntry(id: "o", text: "Rasen düngen morgen")
        let pool = [target, other]

        let neighbors = LeaveOneOut.neighbors(of: target, in: pool, k: 3)

        #expect(!neighbors.contains { $0.id == "t" })
        #expect(neighbors.map(\.id) == ["o"])
    }

    @Test("Rangfolge nach Jaccard, Gleichstand nach id — immer dieselbe Reihenfolge (AC-2)")
    func ranksByJaccardAndBreaksTiesByID() throws {
        let target = try makeEntry(id: "t", text: "Rasen mähen")
        // "Rasen mähen bitte" teilt zwei von drei Wörtern → 2/3, klar vorn.
        let closest = try makeEntry(id: "z", text: "Rasen mähen bitte")
        // Beide teilen genau "Rasen" bei drei Wörtern in der Vereinigung → je 1/3, Gleichstand.
        let tiedA = try makeEntry(id: "a", text: "Rasen wässern")
        let tiedB = try makeEntry(id: "b", text: "Rasen düngen")
        let pool = [target, tiedB, closest, tiedA]

        let neighbors = LeaveOneOut.neighbors(of: target, in: pool, k: 3)

        #expect(neighbors.map(\.id) == ["z", "a", "b"])
    }

    @Test("Wörter unter vier Zeichen tragen keine Ähnlichkeit (AC-3)")
    func similarityWordsDropShortFunctionWords() {
        // "Das", "ist", "da", "für", "uns" sind Funktionswörter unter vier Zeichen.
        let words = LeaveOneOut.similarityWords("Das Auto ist da für uns")

        #expect(words == ["auto"])
    }

    @Test("Bei Stimmengleichstand gewinnt der nähere Nachbar, nicht der zuletzt gesehene (AC-4)")
    func majorityBreaksTiesByNeighborRank() throws {
        let closer = try makeEntry(id: "a", text: "Rasen mähen", duration: "minutes15")
        let further = try makeEntry(id: "b", text: "Rasen düngen", duration: "minutes30")

        let winner = LeaveOneOut.majority(among: [closer, further]) { $0.durationTruth }

        #expect(winner == "minutes15")
    }

    @Test("Ohne Nachbarn keine Vorhersage — und der Satz zählt als Fehltreffer (AC-5)")
    func noNeighborsYieldsNilAndCountsAsMiss() throws {
        let alone = try makeEntry(id: "x", text: "Xylophon stimmen", duration: "minutes15")
        let pair1 = try makeEntry(id: "p1", text: "Rasen mähen", duration: "minutes30")
        let pair2 = try makeEntry(id: "p2", text: "Rasen düngen", duration: "minutes30")
        let pool = [alone, pair1, pair2]

        #expect(LeaveOneOut.neighbors(of: alone, in: pool, k: 3).isEmpty)
        #expect(LeaveOneOut.majority(among: []) { $0.durationTruth } == nil)

        let evaluation = LeaveOneOut.evaluate(pool: pool, k: 1) { $0.durationTruth }

        #expect(evaluation.total == 3)
        #expect(evaluation.withoutPrediction == 1)
        #expect(evaluation.correct == 2)          // die zwei Nachbarn treffen sich gegenseitig
        #expect(evaluation.answered == 2)
        #expect(evaluation.answeredCorrect == 2)
        // Verbindlich ist die Quote über ALLE Sätze: der Satz ohne Nachbarn ist ein Fehltreffer,
        // kein ausgelassener Fall. Sonst sähe eine Regel, die fast nie antwortet, perfekt aus.
        #expect(abs(evaluation.rate - 2.0 / 3.0) < 1e-9)
        #expect(abs(evaluation.rateAmongAnswered - 1.0) < 1e-9)
    }

    @Test("Die Nulllinie wird aus dem Pool gerechnet, nicht hartkodiert (AC-6)")
    func baselineClassIsComputedFromThePool() throws {
        var pool: [Corpus.Entry] = []
        for index in 0..<6 {
            pool.append(try makeEntry(id: "s\(index)", text: "Kurz \(index)", duration: "minutes15"))
        }
        for index in 0..<3 {
            pool.append(try makeEntry(id: "m\(index)", text: "Mittel \(index)", duration: "minutes30"))
        }
        pool.append(try makeEntry(id: "l0", text: "Lang", duration: "minutes60"))

        #expect(LeaveOneOut.baselineClass(pool: pool) { $0.durationTruth } == "minutes15")
    }

    @Test("Kontextmengen sind unabhängig von Schreibweise und Reihenfolge dieselbe Klasse (AC-7)")
    func contextClassNormalisesCaseAndOrder() {
        let first = LeaveOneOut.contextClass(["Computer", "Learning"])
        let second = LeaveOneOut.contextClass(["learning", "computer"])

        #expect(first == second)
        #expect(first == ["computer", "learning"])
    }

    @Test("McNemar: keine Diskordanz heißt p = 1, und die Formel trifft die nachgerechneten Werte (AC-8)")
    func mcNemarMatchesHandCalculatedValues() {
        let identical = [true, false, true, true]
        let noDiscordance = LeaveOneOut.mcNemar(ruleCorrect: identical, baselineCorrect: identical)
        #expect(noDiscordance.b == 0)
        #expect(noDiscordance.c == 0)
        #expect(noDiscordance.pValue == 1.0)

        // b = 9, c = 1 → 2 · (C(10,0) + C(10,1)) / 2^10 = 22/1024
        let nine = LeaveOneOut.mcNemar(
            ruleCorrect: Array(repeating: true, count: 9) + [false],
            baselineCorrect: Array(repeating: false, count: 9) + [true]
        )
        #expect(nine.b == 9)
        #expect(nine.c == 1)
        #expect(abs(nine.pValue - 22.0 / 1024.0) < 1e-9)
        #expect(nine.pValue < 0.05)

        // b = 8, c = 2 → 2 · (1 + 10 + 45) / 1024 = 112/1024 ≈ 0,1094: knapp ÜBER 0,05. Der Fall
        // steht hier, damit die Schwelle aus dem Abbruchkriterium später nicht großzügiger
        // gelesen wird, als sie bei n = 10 tatsächlich ist.
        let eight = LeaveOneOut.mcNemar(
            ruleCorrect: Array(repeating: true, count: 8) + [false, false],
            baselineCorrect: Array(repeating: false, count: 8) + [true, true]
        )
        #expect(eight.b == 8)
        #expect(eight.c == 2)
        #expect(abs(eight.pValue - 112.0 / 1024.0) < 1e-9)
        #expect(eight.pValue > 0.05)
    }
}

/// Writes the leave-one-out report from the local FocusBlox truth export. Gated on that file:
/// it is personal, gitignored data and never exists in CI. Calls no model and touches no device —
/// plain in-memory string handling over a corpus already on disk.
@Suite(.enabled(if: FileManager.default.fileExists(atPath: focusBloxTruthURL.path)))
struct RuleLeaveOneOutReportTests {

    @Test("Schreibt den Regel-Auslass-Bericht mit allen Pflichtspalten, ohne Modell- oder Geräteaufruf (AC-9)")
    func writesReport() throws {
        let entries = try JSONDecoder().decode([Corpus.Entry].self,
                                               from: Data(contentsOf: focusBloxTruthURL))
        let kValues = [1, 3, 5]

        var report = """
        # Regel-Auslass-Test: Wortüberlappung als Nachbarsuche (Spike #69, #131)

        Auslass-Test ohne Modell: für jede Aufgabe entscheiden die k ähnlichsten *anderen* Aufgaben
        per Mehrheit über ein Merkmal. Ähnlichkeit ist der Jaccard-Koeffizient über die Wortmengen
        der Titel, gefiltert auf Wörter ab vier Zeichen.

        | Merkmal | Pool | Methode |
        |---|---|---|
        | Kontexte | \(entries.filter { $0.contextsTruth != nil }.count) | exakte Mengengleichheit |
        | Dauer | \(entries.filter { $0.durationTruth != nil }.count) | exakte Gleichheit |
        | Energie | \(entries.filter { $0.energyTruth != nil }.count) | exakte Gleichheit |

        Korpus: `docs/reference/focusblox-corpus.json` · Methode: Regel-Auslass-Test, kein Modell,
        kein Gerät.

        ## Ergebnis je Merkmal und k

        | Merkmal | k | Trefferquote | ... unter beantworteten | ohne Nachbarn | Nulllinie | Abstand | b | c | p-Wert | Urteil |
        |---|---|---|---|---|---|---|---|---|---|---|

        """

        func line<Value: Hashable>(
            _ name: String,
            pool: [Corpus.Entry],
            value: (Corpus.Entry) -> Value?
        ) -> (text: String, met: Bool) {
            var text = ""
            var met = false
            let baseline = LeaveOneOut.baselineClass(pool: pool, value: value)
            let baselineCorrect = pool.map { value($0) == baseline }
            let baselineRate = pool.isEmpty ? 0
                : Double(baselineCorrect.filter { $0 }.count) / Double(pool.count)

            for k in kValues {
                let evaluation = LeaveOneOut.evaluate(pool: pool, k: k, value: value)
                let test = LeaveOneOut.mcNemar(ruleCorrect: evaluation.ruleCorrect,
                                               baselineCorrect: baselineCorrect)
                let margin = evaluation.rate - baselineRate
                let passes = margin >= 0.10 && test.pValue < 0.05
                met = met || passes
                text += "| \(name) | \(k) "
                    + "| \(percent(evaluation.rate)) | \(percent(evaluation.rateAmongAnswered)) "
                    + "| \(evaluation.withoutPrediction) | \(percent(baselineRate)) "
                    + "| \(percent(margin)) | \(test.b) | \(test.c) "
                    + "| \(String(format: "%.4f", test.pValue)) "
                    + "| \(passes ? "erfüllt" : "nicht erfüllt") |\n"
            }
            return (text, met)
        }

        let contextPool = entries.filter { $0.contextsTruth != nil }
        let durationPool = entries.filter { $0.durationTruth != nil }
        let energyPool = entries.filter { $0.energyTruth != nil }

        let contexts = line("Kontexte", pool: contextPool) { entry in
            entry.contextsTruth.map(LeaveOneOut.contextClass)
        }
        let duration = line("Dauer", pool: durationPool) { $0.durationTruth }
        let energy = line("Energie", pool: energyPool) { $0.energyTruth }
        report += contexts.text + duration.text + energy.text

        report += """

        ## Nebenspalten für Kontexte (nur zur Nachprüfbarkeit der Metrikwahl)

        Verbindlich ist allein die exakte Mengengleichheit oben. Die folgenden zwei Lesarten stehen
        hier, damit die Metrikwahl überprüfbar bleibt — auf sie stützt sich keine Entscheidung.

        | k | enthält erwarteten Kontext | Jaccard-Mittel |
        |---|---|---|

        """
        for k in kValues {
            var contains = 0
            var jaccardSum = 0.0
            for entry in contextPool {
                guard let truth = entry.contextsTruth.map(LeaveOneOut.contextClass) else { continue }
                let neighbors = LeaveOneOut.neighbors(of: entry, in: contextPool, k: k)
                let predicted = LeaveOneOut.majority(among: neighbors) { candidate in
                    candidate.contextsTruth.map(LeaveOneOut.contextClass)
                } ?? []
                if !predicted.intersection(truth).isEmpty { contains += 1 }
                let union = predicted.union(truth)
                jaccardSum += union.isEmpty ? 0 : Double(predicted.intersection(truth).count) / Double(union.count)
            }
            let total = Double(max(contextPool.count, 1))
            report += "| \(k) | \(percent(Double(contains) / total)) "
                + "| \(percent(jaccardSum / total)) |\n"
        }

        report += """

        ## Urteil nach der vorab festgelegten Schwelle

        Erfüllt heißt: bei mindestens einem k liegt die Trefferquote mindestens 10 Prozentpunkte
        über der Nulllinie **und** der zweiseitige McNemar-Exakttest ergibt p < 0,05.

        - Kontexte: \(contexts.met ? "erfüllt" : "nicht erfüllt")
        - Dauer: \(duration.met ? "erfüllt" : "nicht erfüllt")
        - Energie: \(energy.met ? "erfüllt" : "nicht erfüllt")

        ## Grenzen dieser Zahlen

        - Der Korpus trägt gepflegte Titel als Rohtext (`scripts/export-focusblox-corpus.swift`
          setzt `rawText: title`). Jede Zahl hier gilt für Titel, nicht für diktierten Rohtext, wie
          ihn das Produkt verarbeitet.
        - Geprüft ist ein Mechanismus: Wortüberlappung. Ein Nullergebnis widerlegt diesen
          Mechanismus, nicht Annahme B1 insgesamt und nicht den Modellweg.
        - Der Ähnlichkeitsfilter verwirft Wörter unter vier Zeichen und damit kurze Inhaltswörter
          („Tee", „Bad", „App").
        - Bei Kontexten ist die Stichprobe klein genug, dass ein realer Vorsprung von 10 bis 12
          Punkten an der Signifikanz scheitern kann; bei Dauer und Energie kann umgekehrt ein
          signifikanter Vorsprung unter 10 Punkten als „nicht erfüllt" gelten.

        """

        try report.write(to: leaveOneOutReportURL, atomically: true, encoding: .utf8)

        let written = try String(contentsOf: leaveOneOutReportURL, encoding: .utf8)
        #expect(written.contains("| Merkmal | k | Trefferquote |"))
        #expect(written.contains("p-Wert"))
        #expect(written.contains("ohne Nachbarn"))
        #expect(written.contains("Nulllinie"))
        for name in ["Kontexte", "Dauer", "Energie"] {
            #expect(written.contains("- \(name): "))
        }
    }
}
