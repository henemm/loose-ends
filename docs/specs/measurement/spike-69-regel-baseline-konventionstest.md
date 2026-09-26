---
entity_id: spike-69-regel-baseline-konventionstest
type: feature
created: 2026-09-25
updated: 2026-09-25
status: draft
workflow: spike-69-retrieval-beispiele
---

# Spec: Spike #69, Ticket A — Regel-Baseline für den Konventionstest (B1)

**Status:** draft · **Workflow:** spike-69-retrieval-beispiele · **Erstellt:** 2026-09-25 · **Aktualisiert:** 2026-09-25

## Freigabe

- [ ] Freigegeben

## Problem

Annahme B1 (`docs/project/06-annahmen-und-experimente.md`, Zeile 131: „Retrieval lernt wirklich")
ist ungemessen. ADR-5 (`docs/project/00-entscheidungen.md:94`, „Lernen ist Retrieval, kein
Training") legt fest, dass fünf ähnliche alte Aufgaben als Prompt-Beispiele das Modell zu Hennings
Konventionen lenken sollen — bisher ohne jeden Beleg, dass das funktioniert.
`EnrichmentCoordinator.examples(in:limit:)` (`Shared/Enrichment/EnrichmentCoordinator.swift:145-163`)
liefert heute nur die letzten fünf erledigten Aufgaben nach Datum, ein Platzhalter, keine
Ähnlichkeitssuche. B1s Abbruchkriterium hat zwei Teile: der Auslass-Test (Differenz ≤ Rauschen) und
der Konventionstest (< 8/10 Treffer). Henning hat den vollen Zuschnitt (Regel-Baseline +
Embedding-Auslass-Test + Konventionstest in einem Durchgang) am 2026-09-25 verworfen, weil er das
Scoping-Limit real sprengt (geschätzt 6 Dateien, ~350–400 LoC) — siehe „Entscheidung zum Zuschnitt"
in `docs/context/spike-69-retrieval-beispiele.md`. Dieser Schnitt liefert nur den ersten,
kleineren Schritt: die Regel-Baseline für den Konventionstest, als Nulllinie, an der sich ein
mögliches Embedding-Retrieval erst messen lassen muss.

**Zentraler Befund, der den Korpus-Zuschnitt bestimmt:** Der FocusBlox-Export
(`scripts/export-focusblox-corpus.swift`) kennt kein `project`-Feld — die `ZLOCALTASK`-Tabelle hat
dafür keine Spalte (`docs/project/02-datenmodell-und-ansichten.md` nennt sie nicht in der
Mapping-Tabelle, dieselbe Lücke, die Spike #108 bereits für `people`/`project` bei den
Selbstkonsistenz-Feldern festgestellt hat). Wort→Projekt-Muster können deshalb nicht aus echten
FocusBlox-Daten stammen, nur Wort→Kontext-Muster (das `contexts`-Feld existiert im Export und hat
echte Wahrheit, siehe `contextsTruth` in `Corpus.Entry`, Spike #108). Dieser Schnitt beschränkt den
Konventionstest deshalb auf zehn Wort→Kontext-Muster; Wort→Projekt bleibt zurückgestellt, siehe
„Nicht in diesem Schnitt".

## Zweck

Dieser Schnitt misst, ob sich Hennings Konventionen (welches Kernwort in einem Text zu welchem
Kontext gehört) allein aus drei früheren Korrekturen ableiten lassen — ohne Modell, ohne Embedding,
mit reiner Zeichenkettenverarbeitung. Er liefert die Nulllinie des Konventionstests aus B1: einen
Korpus mit zehn Wort→Kontext-Mustern (drei Korrekturen + eine Sonde je Muster), eine Regel, die aus
den drei Korrekturen lernt und die Sonde vorhersagt, und einen Bericht mit der Trefferquote über
alle zehn Muster sowie der daraus folgenden Entscheidung, ob ein Folge-Ticket für den
Embedding-Auslass-Test (Ticket B) nötig ist. Nicht Teil dieses Schnitts: der Auslass-Test selbst,
jede Embedding-Anbindung (`NLContextualEmbedding`), und die Entscheidung über ADR-5 — die folgt erst
aus dem Ergebnis dieses und eines möglichen Ticket B.

## Quelle

- **Datei:** `Measurement/ConventionCorpus.swift` (neu)
  **Bezeichner:** `enum ConventionCorpus` — `struct Pattern`, `static func load(fileName:) throws -> [Pattern]`
- **Datei:** `Measurement/convention-corpus.json` (neu)
  **Bezeichner:** zehn Wort→Kontext-Muster im `Pattern`-Format
- **Datei:** `Measurement/RuleBaseline.swift` (neu)
  **Bezeichner:** `enum RuleBaseline` — `static func predict(pattern:) -> String?`,
  `static func evaluate(patterns:) -> [Outcome]`
- **Datei:** `LooseEndsTests/ConventionBaselineTests.swift` (neu)
  **Bezeichner:** `struct ConventionBaselineTests`
- **Datei:** `docs/reference/retrieval-convention-spike.md` (neu)
  Bericht: Trefferquote, Ergebnis je Muster, Entscheidung zu Ticket B

## Acceptance Criteria

- **AC-1 `ConventionCorpus` lädt zehn Wort→Kontext-Muster:** Given
  `Measurement/convention-corpus.json` mit zehn Einträgen, jeder mit drei `corrections`
  (`text: String`, `context: String`) und einer `probe` (`text: String`, `expectedContext: String`)
  / When `ConventionCorpus.load(fileName: "convention-corpus")` aufgerufen wird / Then liefert es
  genau zehn `Pattern`-Werte mit je drei Korrekturen und einer Sonde, unverändert übernommen (kein
  Datenverlust, keine Kürzung).
- **AC-2 Kernwort-Ableitung nutzt die vorhandene Tokenisierung:** Given eine Korrektur mit Text
  „Rasen mähen, bevor die Nachbarn kommen" und Kontext „Garten" sowie eine Sonde „Rasen wässern,
  bevor es zu heiß wird" / When `RuleBaseline.predict(pattern:)` die drei Korrekturen und die Sonde
  über `TitleCheck.words(in:)` tokenisiert / Then erkennt sie „Rasen" als das Wort, das in allen
  drei Korrekturen und in der Sonde vorkommt, und ordnet ihm den Kontext „Garten" zu.
- **AC-3 Mehrheitsentscheid bei mehrdeutigem Wort:** Given drei Korrekturen, bei denen ein
  gemeinsames Wort zweimal zu Kontext „Garten" und einmal zu Kontext „Keller" führt / When
  `RuleBaseline.predict(pattern:)` die Wort→Kontext-Zuordnung aufbaut / Then gewinnt „Garten"
  (2 von 3), nicht der zuletzt gesehene Wert — die Funktion zählt Häufigkeiten, sie überschreibt
  nicht einfach den letzten Treffer.
- **AC-4 Kein Treffer liefert `nil`, keinen geratenen Kontext:** Given eine Sonde, deren Wörter mit
  keinem der aus den drei Korrekturen gelernten Kernwörter übereinstimmen / When
  `RuleBaseline.predict(pattern:)` aufgerufen wird / Then ist das Ergebnis `nil` (Analogie zu
  `ImportanceUrgencyRule`: kein erzwungener Default).
- **AC-5 Auswertung über alle zehn Muster liefert die Trefferquote:** Given die zehn Muster aus dem
  Konventionstest-Korpus / When `RuleBaseline.evaluate(patterns:)` aufgerufen wird / Then liefert es
  zehn `Outcome`-Werte (Muster-ID, Vorhersage, Wahrheit, `correct: Bool`), und die Anzahl der
  `correct == true`-Werte ergibt die Trefferquote, die der Bericht als „N von 10" ausweist.
- **AC-6 Bericht wird lokal geschrieben, ohne Modell- oder Geräteaufruf:** Given
  `ConventionBaselineTests` läuft mit dem eingebetteten Korpus / When die Suite läuft / Then
  schreibt sie `docs/reference/retrieval-convention-spike.md` mit der Trefferquote, einer Zeile je
  Muster (Kernwort, vorhergesagter Kontext, tatsächlicher Kontext, richtig/falsch) und der
  Entscheidung „Ticket B nötig: ja/nein" nach der ≥ 8/10-Schwelle aus B1 — ohne
  `FoundationModelsEnricher.enrich(_:)` aufzurufen und ohne ein reales Gerät zu benötigen (reine
  Zeichenkettenverarbeitung, läuft im normalen `./scripts/sim.sh unit`-Lauf auf dem Mac).

## Nicht in diesem Schnitt

- Der Embedding-Auslass-Test aus B1 (Differenz mit/ohne k Nachbarn gegen Rauschen). Eigenes,
  ebenfalls kleines Folge-Ticket („Ticket B"), nur falls die Regel-Baseline die 8/10-Schwelle nicht
  erreicht (Entscheidung von Henning, 2026-09-25).
- `NLContextualEmbedding`-Anbindung oder jede andere Ähnlichkeitssuche — im Projekt bisher
  nirgends verwendet, bleibt für Ticket B.
- Wort→Projekt-Muster im Konventionstest. Der FocusBlox-Export kennt kein `project`-Feld (siehe
  „Zentraler Befund" oben); zehn synthetische Wort→Projekt-Muster ohne reale Datenquelle würden
  keine echte Nulllinie liefern, nur eine erfundene. Zurückgestellt, analog zur Rückstellung von
  `people`/`project` in Spike #108 — bei Bedarf ein separater Nachschlag, sobald `TaskItem.project`
  eine reale Datenquelle hat.
- Änderungen an `EnrichmentCoordinator.examples(in:limit:)` oder `FoundationModelsEnricher` — dieser
  Schnitt misst nur, er greift nicht in den Produktpfad ein.
- Die Entscheidung über ADR-5 selbst. Sie hängt vom Ergebnis dieses Schnitts (und ggf. Ticket B) ab,
  ist aber nicht Teil dieser Spec — siehe „Folgeentscheidung" unten.

## Abhängigkeiten

| Baustein | Art | Zweck |
|----------|-----|-------|
| `TitleCheck.words(in:)` (`Measurement/Corpus.swift:278-280`) | Funktion | Bestehende, reine Tokenisierung — wird für die Kernwort-Extraktion wiederverwendet statt eine zweite Tokenisierung zu schreiben. |
| `Corpus.load(fileName:)` (`Measurement/Corpus.swift:121-128`) | Muster | Vorbild für `ConventionCorpus.load(fileName:)`: Bundle-Lookup mit Fallback auf die Datei neben dem Quellcode, damit ein lokaler Skriptlauf ohne Testbundle funktioniert. |
| `ImportanceUrgencyRule` (`Shared/Enrichment/ImportanceUrgencyRule.swift`) | Stil-Vorbild | Reine `enum` mit `static func`, „kein Treffer heißt nil, nie ein erzwungener Default" — Programmierstil für `RuleBaseline`, nicht die Keyword-Logik selbst (die ist musterspezifisch, nicht fest verdrahtet). |
| `docs/reference/date-title-fidelity.md` | Berichtsformat-Vorbild | Kopftabelle mit Metadaten, dann Ergebnistabelle — für diesen Spike ohne Geräte-/Akku-Zeilen, weil keine Modellmessung stattfindet. |
| FocusBlox-Export (287 echte Aufgaben, gitignored, nur lokal bei Henning) | Datenquelle | Inspiriert die zehn Wort→Kontext-Muster; die Sätze im Korpus sind neu geschrieben, nicht wörtlich übernommen (siehe „Technische Umsetzung"). |

## Umfang

### Betroffene Dateien

| Datei | Änderungsart | Beschreibung |
|-------|---------------|--------------|
| `Measurement/ConventionCorpus.swift` | CREATE | `Pattern`-Typ (drei `corrections` + eine `probe`) und `load(fileName:)`, analog zu `Corpus.load`. |
| `Measurement/convention-corpus.json` | CREATE | Zehn Wort→Kontext-Muster, von echten FocusBlox-Häufungen inspiriert, als neue Sätze geschrieben. |
| `Measurement/RuleBaseline.swift` | CREATE | Kernwort-Extraktion über `TitleCheck.words(in:)`, Wort→Kontext-Zuordnung mit Mehrheitsentscheid, Vorhersage je Sonde, `Outcome`-Auswertung über alle Muster. |
| `LooseEndsTests/ConventionBaselineTests.swift` | CREATE | Unit-Tests für AC-1 bis AC-5, plus ein Report-Test für AC-6 (ungated: reine Zeichenkettenverarbeitung, kein Datei-/Modell-Gate nötig). |
| `docs/reference/retrieval-convention-spike.md` | CREATE | Bericht: Trefferquote, Ergebnis je Muster, Entscheidung zu Ticket B — wird vom Test in `ConventionBaselineTests` geschrieben, nicht von Hand gepflegt. |

### Geschätzter Umfang

- Dateien: 5 — innerhalb des Standard-Richtwerts (4-5 Dateien).
- LoC: geschätzt rund +150/-0 (`ConventionCorpus.swift` ~30, `convention-corpus.json` ~40,
  `RuleBaseline.swift` ~50, `ConventionBaselineTests.swift` ~30) — innerhalb der ±250-LoC-Grenze.
- Risiko: NIEDRIG. Reiner Messcode in `Measurement/` und `LooseEndsTests/` (kompiliert laut
  `CLAUDE.md` nie in den Produktpfad), keine neue Abhängigkeit, kein Gerätetestlauf nötig (reine
  Zeichenkettenverarbeitung läuft in Millisekunden im normalen Mac-Testlauf).

## Technische Umsetzung

1. **`Measurement/ConventionCorpus.swift` (neue Datei), Muster `Corpus.swift`:** `struct Pattern:
   Decodable, Sendable, Identifiable` mit `id: String`, `corrections: [Correction]` (`text: String`,
   `context: String`), `probe: Probe` (`text: String`, `expectedContext: String`). `static func
   load(fileName: String = "convention-corpus") throws -> [Pattern]` mit demselben
   Bundle-dann-Datei-neben-Quellcode-Fallback wie `Corpus.load(fileName:)`, damit ein lokaler
   Skript- oder Testlauf ohne gebautes Testbundle funktioniert.
2. **`Measurement/convention-corpus.json` (neue Datei):** zehn Muster, jedes von einer realen
   FocusBlox-Wort→Kontext-Häufung inspiriert (Henning sichtet dafür die 287 exportierten Aufgaben
   lokal, das Skript selbst bleibt unverändert), aber als neue, frei formulierte Sätze geschrieben —
   nie wörtlich aus dem gitignorten Export übernommen, im selben Stil wie die bestehenden Sätze in
   `Measurement/date-title-corpus.json` (z. B. „Heute noch die Mülltonne rausstellen"). Jedes Muster:
   drei `corrections` mit demselben Kernwort und demselben Kontext, eine `probe` mit demselben
   Kernwort ohne expliziten Kontext-Hinweis im Text. Beispiel (illustrativ, die tatsächliche Auswahl
   folgt den echten Häufungen): Kernwort „Rasen", Kontext „Garten", Sonde „Rasen wässern, bevor es zu
   heiß wird".
3. **`Measurement/RuleBaseline.swift` (neue Datei), reine `Foundation`-Zeichenkettenverarbeitung:**
   - `static func predict(pattern: ConventionCorpus.Pattern) -> String?`: tokenisiert jede der drei
     `corrections` sowie die `probe` über `TitleCheck.words(in:)`; ermittelt je Korrektur die Wörter,
     die auch in der Sonde vorkommen (das ist der Rückschluss „welches Wort hat zum Kontext
     geführt"); baut daraus eine Wort→Kontext-Häufigkeitstabelle; wählt für jedes Sonden-Wort mit
     Eintrag in der Tabelle den häufigsten zugeordneten Kontext (Mehrheitsentscheid über die drei
     Korrekturen, nicht „letzter gewinnt" — AC-3); liefert `nil`, wenn kein Sonden-Wort in der
     Tabelle auftaucht (AC-4).
   - `struct Outcome { let patternID: String; let predicted: String?; let expected: String; var
     correct: Bool { predicted == expected } }`.
   - `static func evaluate(patterns: [ConventionCorpus.Pattern]) -> [Outcome]`: ruft `predict`
     für jedes Muster auf und baut die `Outcome`-Liste.
4. **`LooseEndsTests/ConventionBaselineTests.swift` (neue Datei):** Unit-Tests für AC-1 bis AC-5
   gegen kleine, inline definierte `Pattern`-Werte (kein Korpus-Laden nötig für die Logik-Tests) und
   einen zusätzlichen Test, der den eingebetteten Korpus lädt, `evaluate(patterns:)` aufruft und
   `docs/reference/retrieval-convention-spike.md` schreibt (AC-6) — ungated, weil weder Modell noch
   Gerät im Spiel sind und die Datei kein Geheimnis enthält.
5. **Bericht-Format**, angelehnt an `docs/reference/date-title-fidelity.md`, aber ohne
   Geräte-/Akku-/Bauform-Zeilen (keine Modellmessung):
   - Kopftabelle: Korpus (zehn Muster), Messtag, Methode (Regel-Baseline, kein Modell).
   - Ergebnistabelle: eine Zeile je Muster (Kernwort, vorhergesagter Kontext, erwarteter Kontext,
     richtig/falsch).
   - Fazit-Zeile: Trefferquote „N von 10", Entscheidung „Ticket B (Embedding-Auslass-Test) nötig:
     ja/nein" nach der ≥ 8/10-Schwelle aus B1.
6. **Reihenfolge der Umsetzung:** Korpus-Typ und JSON zuerst (Datengrundlage), dann `RuleBaseline`
   (Logik), dann die Tests (RED vor der Logik-Implementierung, GREEN danach), zuletzt der
   Report-Test — jeder Schritt baut auf dem vorigen auf.

### Alternativen

- **Wort→Projekt-Muster zusätzlich aufnehmen, mit synthetischen (nicht FocusBlox-inspirierten)
  Beispielen.** Würde den Konventionstest vollständiger gegenüber der Issue-Formulierung
  („Wort → Kontext, Wort → Projekt") machen, aber ohne reale Datenquelle wäre die Nulllinie
  erfunden statt gemessen — ein Wort→Projekt-Muster ohne echte FocusBlox-Häufung sagt nichts über
  Hennings tatsächliche Konventionen. Verworfen für diesen Schnitt, analog zur Rückstellung von
  `project` in Spike #108 (dort fehlte ebenfalls die Wahrheit in der Datenquelle). Kippt keine
  bestehende ADR.
- **`Corpus.Entry` um die Konventionstest-Struktur erweitern statt eines eigenen `ConventionCorpus`-
  Typs.** Würde eine bestehende Ladefunktion wiederverwenden, aber `Corpus.Entry` modelliert
  Ist-Werte einer einzelnen Aufgabe (`*Truth`-Felder), keine „drei Korrekturen + Sonde"-Struktur —
  eine Erweiterung würde die Semantik von `Corpus.Entry` verwässern und optionale Felder erzwingen,
  die für den Konventionstest nie leer sind. Verworfen, ein eigener kleiner Typ ist klarer und
  kostet nur eine zusätzliche Datei. Kippt keine bestehende ADR.
- **Den vollen Zuschnitt aus der Issue in einem Durchgang** (Regel-Baseline + Embedding-Auslass-Test
  + Konventionstest). Bereits von Henning am 2026-09-25 verworfen (siehe „Entscheidung zum
  Zuschnitt" im Analyse-Kontext): sprengt das Scoping-Limit real (~6 Dateien, ~350–400 LoC). Dieser
  Schnitt ist der erste, kleinere Teil.

## Testplan

### Automatisierte Tests (TDD RED)

- [ ] `ConventionBaselineTests`, Fall Laden: GIVEN `Measurement/convention-corpus.json` mit zehn
  Mustern / WHEN `ConventionCorpus.load(fileName:)` aufgerufen wird / THEN liefert es genau zehn
  `Pattern`-Werte mit je drei Korrekturen und einer Sonde, unverändert übernommen (AC-1).
- [ ] `ConventionBaselineTests`, Fall Kernwort-Ableitung: GIVEN eine Korrektur „Rasen mähen, bevor
  die Nachbarn kommen" / Kontext „Garten" (dreifach mit demselben Kernwort) und eine Sonde „Rasen
  wässern, bevor es zu heiß wird" / WHEN `RuleBaseline.predict(pattern:)` aufgerufen wird / THEN ist
  das Ergebnis „Garten" (AC-2).
- [ ] `ConventionBaselineTests`, Fall Mehrheitsentscheid: GIVEN drei Korrekturen mit gemeinsamem
  Kernwort, zwei mit Kontext „Garten", eine mit Kontext „Keller" / WHEN `RuleBaseline.predict
  (pattern:)` aufgerufen wird / THEN ist das Ergebnis „Garten" (2 von 3), nicht der zuletzt gesehene
  Wert (AC-3).
- [ ] `ConventionBaselineTests`, Fall kein Treffer: GIVEN eine Sonde, deren Wörter mit keinem
  gelernten Kernwort übereinstimmen / WHEN `RuleBaseline.predict(pattern:)` aufgerufen wird / THEN
  ist das Ergebnis `nil` (AC-4).
- [ ] `ConventionBaselineTests`, Fall Auswertung: GIVEN die zehn Muster aus dem eingebetteten Korpus
  / WHEN `RuleBaseline.evaluate(patterns:)` aufgerufen wird / THEN liefert es zehn `Outcome`-Werte,
  und die Anzahl `correct == true` entspricht der manuell nachgerechneten Trefferquote (AC-5).
- [ ] `ConventionBaselineTests`, Fall Bericht: GIVEN der eingebettete Korpus und
  `RuleBaseline.evaluate(patterns:)` / WHEN die Suite läuft / THEN existiert
  `docs/reference/retrieval-convention-spike.md` mit Trefferquote, einer Zeile je Muster und der
  Entscheidung „Ticket B nötig: ja/nein"; kein Aufruf an `FoundationModelsEnricher.enrich(_:)` im
  gesamten Testlauf (AC-6).
- [ ] Bestehende Suiten bleiben grün: GIVEN der neue Code / WHEN `./scripts/sim.sh unit` läuft /
  THEN bestehen `CorpusTests`, `MeasurementRunTests`, `SelfConsistencyTests`, `EnrichmentTests`
  unverändert, weil dieser Schnitt keinen Produktpfad berührt und keine bestehende Datei ändert
  außer den fünf neu angelegten.

Kein UI-Test: Dieser Schnitt ändert keine SwiftUI-View und keinen Produktcode — die gesamte
Erweiterung lebt in `Measurement/` und `LooseEndsTests/`. Kein Test ruft das Modell auf
([[feedback-phone-is-not-a-test-bench]] bleibt gewahrt): `RuleBaseline` ist reine In-Memory-
Zeichenkettenverarbeitung, der Report-Test liest nur den lokal eingebetteten Korpus. Der Nachweis
läuft vollständig über den Mac-Testlauf, kein Gerät nötig.

## Definition of Done

- [ ] AC-1 bis AC-6 erfüllt, belegt durch die im Testplan genannten Tests
- [ ] `./scripts/sim.sh unit` grün, inklusive aller bestehenden Suiten
- [ ] CI grün
- [ ] PR mit `Closes` auf das Sub-Issue von #69 für Ticket A gemergt
- [ ] Hennings Hauptordner nachgezogen und Projekt neu erzeugt
  (`bash ~/.claude/scripts/loose-ends-sync-main.sh`)
- [ ] `docs/reference/retrieval-convention-spike.md` existiert mit der tatsächlichen Trefferquote
  und der Entscheidung zu Ticket B (der Report-Test schreibt ihn synchron beim Testlauf, kein
  separater Geräte-Mehrtageslauf nötig, weil die Regel in Millisekunden läuft)

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Der gesamte Code liegt in `Measurement/` und `LooseEndsTests/` — Messcode, kein
  Produktpfad, keine neue Abhängigkeit. Die Projektregel „Regeln vor Modell" ist hier nicht als
  Prüfpflicht einschlägig, weil dieser Schnitt kein Modell vorschlägt oder ersetzt: Er baut selbst
  die Regel-Alternative zum Modell-Retrieval aus ADR-5 und liefert die Nulllinie, gegen die sich
  Retrieval oder Modell in einem möglichen Ticket B erst messen müssten. Erreicht die Regel-Baseline
  die 8/10-Schwelle aus B1, stellt das nicht nur den Zuschnitt von #26 zur Disposition, sondern
  potenziell ADR-5 selbst („Lernen ist Retrieval, kein Training" könnte zu „Regeln aus Korrekturen,
  kein Retrieval nötig" werden) — diese Entscheidung fällt aber erst nach dem Messergebnis, nicht in
  dieser Spec.

## Changelog

- 2026-09-25: Spec aus dem Analyse-Kontext (`docs/context/spike-69-retrieval-beispiele.md`,
  Abschnitt „Analysis", Zuschnitt-Entscheidung Henning 2026-09-25) erstellt.
