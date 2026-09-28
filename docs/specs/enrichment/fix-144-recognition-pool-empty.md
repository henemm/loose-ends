---
entity_id: fix-144-recognition-pool-empty
type: bugfix
created: 2026-09-28
updated: 2026-09-28
status: draft
workflow: fix-144-recognition-pool-empty
---

# Spec: #144 — Ohne Apple Intelligence greift die Wiedererkennung nie (Vergleichsmenge bleibt leer)

## Approval

- [ ] Approved

## Purpose

Auf einem Gerät ohne Apple Intelligence (Simulator, nicht berechtigtes Gerät, abgeschaltete
Funktion) übernimmt eine wortgleiche Zweiterfassung nie Dauer und Kontexte der ersten Aufgabe: Die
Vergleichsmenge der Wiedererkennung (`RecognitionRule`, #136) hängt am Modell-Vermerk
`processedAt`, der ohne Modelllauf nie gesetzt wird. Damit greift ein Regelmechanismus, der
ausdrücklich kein Modell braucht, faktisch nie — ein Verstoß gegen „Rules before the model"
(CLAUDE.md). Diese Spec gibt dem Regelschritt einen eigenen, vom Modell unabhängigen Vermerk
(`rulesAppliedAt`) und liest die Vergleichsmenge über beide Vermerke, ohne eine der bestehenden
Zusagen aus ADR-4, #95 (AC-7/AC-8) oder #136 (AC-7) zu brechen.

## Source

- **Datei:** `Shared/Enrichment/EnrichmentCoordinator.swift`
- **Bezeichner:** `func processPending()`, `private static func recognitionInputs(in:)`
- **Datei:** `Shared/Models/TaskItem.swift`
- **Bezeichner:** `var rulesAppliedAt: Date?` (neu, neben `var processedAt: Date?`)

## Dependencies

| Baustein | Art | Zweck |
|---|---|---|
| `RecognitionRule` (#136) | Reine Regel | Bekommt nur endlich Material — bleibt selbst unberührt, keine SwiftData-Kenntnis |
| `EnrichmentWriter.apply` (#95, #117, #136) | Vorbild | Einzige heutige Schreibstelle für `processedAt` (Z. 94); Vorbild für „Vermerk unabhängig vom Ausgang setzen" |
| `Shared/Models/TaskItem.swift` | Modell | Additives optionales Feld nach dem Muster von `showInCalendar`, `repeatRule` — Lightweight Migration, kein `SchemaMigrationPlan` im Projekt vorhanden |
| ADR-4 (`docs/project/00-entscheidungen.md:87-92`) | Entscheidung | „Veredelung genau einmal" für das Modell; wird um `rulesAppliedAt` ergänzt, nicht revidiert |
| `docs/specs/enrichment/feat-136-wiedererkennung.md` (AC-6/AC-7/AC-8) | Spec | AC-7 wird umformuliert (Abschnitt „Implementation Details"), AC-6 und AC-8 bleiben unverändert gültig |
| `docs/specs/enrichment/feat-95-parser-in-app.md` (AC-7/AC-8) | Spec | Bestätigt das Muster „Regelschritt unabhängig vom Modell-Gate" — bleibt unverändert |
| `LooseEndsTests/EnrichmentTests.swift`, `RecognitionPoolReachabilityTests` (Z. 691-746) | Test | Bereits committete RED-Tests (50fcb8c), müssen grün werden |

## Scope

### Affected Files

| Datei | Änderungsart | Beschreibung |
|---|---|---|
| `Shared/Models/TaskItem.swift` | MODIFY | `var rulesAppliedAt: Date?` direkt unter `var processedAt: Date?` (Z. 19) einfügen, Kommentarzeile zur Bedeutung |
| `Shared/Enrichment/EnrichmentCoordinator.swift` | MODIFY | In `processPending()` (Z. 48-74): `task.rulesAppliedAt = Date()` unmittelbar nach `applyRules(...)` (Z. 49), außerhalb des `if modelUnavailable == nil`-Blocks (Z. 50) und außerhalb des `try/catch` (Z. 58-64). `recognitionInputs(in:)` (Z. 157-163) auf zwei `FetchDescriptor` (`processedAt != nil`, `rulesAppliedAt != nil`) plus Zusammenführung per `id` umgestellt |
| `LooseEndsTests/EnrichmentTests.swift` | MODIFY | Beide RED-Tests (Z. 691-746) bleiben inhaltlich stehen; `poolNeverFillsWithoutTheModel` (Z. 731-745) bekommt eine neue Formulierung mit angepasstem Prädikat (siehe „Implementation Details"). Vier neue Fälle: Fehlschlag-Pfad, Bestandsdaten, Dedupe, Pending-Fetch unverengt |
| `LooseEndsUITests/RecognitionWalkthroughTests.swift` | CREATE | Bedienablauf „erfassen → Werte von Hand setzen → wortgleich erneut erfassen → Werte sind da" im Simulator, nach dem Muster von `CaptureSmokeTests.swift` |
| `docs/project/00-entscheidungen.md` | MODIFY | ADR-4 (Z. 87-92) um einen Satz zu `rulesAppliedAt` ergänzt |
| `docs/specs/enrichment/feat-136-wiedererkennung.md` | MODIFY | AC-7 (Z. 433-435) umformuliert, Implementierungsnotiz zur Vergleichsmenge (Abschnitt „3. Vergleichsmenge", Z. 200-223) um einen Verweis auf `rulesAppliedAt` ergänzt |

### Estimated Changes

- Dateien: 6 (davon 2 Produktivcode — unter der 4-5-Richtgröße aus CLAUDE.md)
- LoC: Produktivcode +25/-8, Tests +120, Doku +20 — zusammen unter 250 LoC

## Implementation Details

**1. Neues Feld, additiv, ohne Migrationsplan.**

```swift
var statusRaw: String = TaskStatus.unprocessed.rawValue
var processedAt: Date?       // "das Modell hat diese Aufgabe gesehen" (ADR-4, seit #95)
var rulesAppliedAt: Date?    // "der Regelschritt lief" — unabhängig vom Modell (#144)
```

`processedAt` behält seine heutige Bedeutung unverändert. Der Pending-Fetch
(`processedAt == nil && statusRaw == unprocessed`, `EnrichmentCoordinator.swift:38`) bleibt
**unverengt**: `rulesAppliedAt` ist kein Ausschlusskriterium für den Modell-Nachzügler-Lauf. Sonst
verlöre eine ohne Apple Intelligence erfasste Aufgabe für immer die Chance auf Titel, Energie,
Personen und Projekt, sobald das Modell später verfügbar wird — exakt der Fehler, den #95 bereits
einmal behoben hat (`EnrichmentTests.swift:262-290`).

**2. Vermerk vor dem Modellaufruf, außerhalb von `try`/`catch`.**

```swift
for task in pending {
    applyRules(to: task, recognitionPool: recognition.pool, tasksByID: recognition.tasksByID)
    task.rulesAppliedAt = Date()   // unabhängig davon, ob das Modell lief oder glückte (#144)
    if modelUnavailable == nil {
        // … Modellaufruf wie bisher, inkl. catch …
    }
    do { try context.save() } catch { … }
}
```

Damit greift der Vermerk in beiden Fehlerpfaden aus der Analyse: fehlendes Modell (`modelUnavailable
!= nil`) und fehlgeschlagener Modellaufruf (`catch`-Zweig, Z. 62-64) — Letzteres betrifft auch
Hennings iPhone 16 Pro, nicht nur den Simulator.

**3. Vergleichsmenge über zwei Fetches, kein `#Predicate` mit `||`.**

Im gesamten Projekt existiert kein einziges `#Predicate` mit `||` (vier Prädikate insgesamt, alle
`==`/`&&`, Volltextsuche negativ für ein bestehendes Gegenbeispiel). Ob SwiftData mit CloudKit-Store
ein ODER-Prädikat korrekt übersetzt, ist unbelegt — deshalb zwei getrennte `FetchDescriptor` und
Zusammenführung per `id` in Swift, nach demselben Dictionary-Idiom, das `recognitionInputs` bereits
für die `tasksByID`-Map verwendet (`EnrichmentCoordinator.swift:162`):

```swift
private static func recognitionInputs(
    in context: ModelContext
) throws -> (pool: [RecognitionRule.Candidate], tasksByID: [UUID: TaskItem]) {
    let byModel = try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.processedAt != nil }))
    let byRules = try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.rulesAppliedAt != nil }))
    let merged = Dictionary((byModel + byRules).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    let tasks = Array(merged.values)
    return (recognitionCandidates(in: tasks), merged)
}
```

`uniquingKeysWith: { first, _ in first }` löst die Bestandsdaten- und die Dedupe-Frage in einem
Zug: Eine Aufgabe, die vor dieser Änderung schon veredelt wurde (lokal oder per CloudKit von einem
Gerät mit Apple Intelligence) trägt `processedAt != nil, rulesAppliedAt == nil` und erscheint über
`byModel`. Eine Aufgabe mit beiden Vermerken erscheint in beiden Listen, aber genau einmal im
zusammengeführten Ergebnis.

**4. Bewusste Folge — AC-7 von #136 wird umformuliert, nicht abgeschwächt.**

Ab dem **zweiten** Durchgang kann eine Aufgabe, deren Regelschritt bereits in einem früheren
Durchgang lief (`rulesAppliedAt != nil`), aber noch kein Modell gesehen hat (`processedAt == nil`,
`status` bleibt `.unprocessed`), Quelle für eine andere, noch unverarbeitete Aufgabe werden. Der
bestehende AC-7-Test (`EnrichmentTests.swift:538-554`, `unprocessedTasksAreNotPartOfThePool`) bleibt
grün, weil der Pool **vor der Schleife** gefüllt wird (`EnrichmentCoordinator.swift:46`) und im
ersten Durchgang noch keine der beiden gleichzeitig unverarbeiteten Aufgaben einen der beiden
Vermerke trägt — die strukturelle Garantie „keine Aufgabe desselben Durchgangs kann Quelle für eine
andere sein" gilt unverändert, weil sie aus dem Fetch-Zeitpunkt folgt, nicht aus dem Feldnamen.
Was sich ändert, ist nur die **Formulierung** von AC-7: „unverarbeitete Aufgaben" wird zu „Aufgaben,
deren Regelschritt noch nicht lief" (siehe Änderung an `feat-136-wiedererkennung.md` unten).

Sachlich ist das kein aufgeweichter Schutz: Ohne Modell können Dauer und Kontexte überhaupt nur aus
einer Nutzereingabe oder aus der Wiedererkennung selbst stammen — das Saatkorn ist also immer ein
Nutzerwert, und `RecognitionRule.winner` (`RecognitionRule.swift:76-94`) bevorzugt nutzergesetzte
Werte ausdrücklich. Ein Selbsttreffer ist wirkungslos: Die Guards `Feld == nil`
(`EnrichmentCoordinator.swift:190, 207`) und `!EnrichmentWriter.userHasTouched(…)` blockieren jedes
Schreiben auf ein bereits gesetztes oder vom Nutzer geleertes Feld.

**5. `poolNeverFillsWithoutTheModel` wird an die neue Lesart angepasst.** Der Test prüft heute
wörtlich `$0.processedAt != nil` (`EnrichmentTests.swift:743`). Unter dieser Spec bleibt
`processedAt` ohne Modell für immer `nil` — das ist gewollt (Punkt 1). Der Test wird deshalb nicht
geschwächt, sondern auf das tatsächliche Lesekriterium der Vergleichsmenge umgestellt: Das Prädikat
wechselt von `$0.processedAt != nil` auf `$0.rulesAppliedAt != nil`, die Aussage
(„wer die Regeln durchlaufen hat, gehört in die Vergleichsmenge", `pool.count == 3`) bleibt exakt
erhalten. Titel und Beschreibung des Tests werden von „bekommt … einen Verarbeitungs-Vermerk" auf
„bekommt … den Regel-Vermerk" präzisiert, damit die Assertion zur Aussage passt.

## Test Plan

### Automated Tests (TDD RED)

- **GIVEN** eine Aufgabe ohne Apple Intelligence erfasst, Dauer und Kontext vom Nutzer gesetzt, dann
  wortgleich erneut erfasst **WHEN** `processPending()` beide Male läuft **THEN** übernimmt die
  zweite Aufgabe Dauer `.minutes30` und Kontext „Garten" der ersten — bereits committeter RED-Test
  `recognitionWorksWithoutTheModel` (`EnrichmentTests.swift:696-726`), grün ohne Abschwächung.
- **GIVEN** drei frisch erfasste Aufgaben ohne Apple Intelligence **WHEN** `processPending()` läuft
  **THEN** haben alle drei `rulesAppliedAt != nil` und liegen in der Vergleichsmenge —
  umbenannter/angepasster RED-Test `poolNeverFillsWithoutTheModel` → `ruleMarkerFillsThePoolWithoutTheModel`
  (`EnrichmentTests.swift:731-745`, Prädikat auf `rulesAppliedAt` umgestellt wie oben beschrieben).
- **GIVEN** ein `StubEnricher`, dessen `enrich(_:)` wirft **WHEN** `processPending()` läuft **THEN**
  trägt die betroffene Aufgabe trotzdem `rulesAppliedAt != nil` — neuer Test, deckt den
  `catch`-Zweig (`EnrichmentCoordinator.swift:62-64`) ab, der auch Hennings iPhone treffen kann, nicht
  nur den Simulator.
- **GIVEN** eine Aufgabe mit `processedAt != nil, rulesAppliedAt == nil` (Bestandsdatum, z. B. über
  `makeProcessed` erzeugt) und eine zweite, wortgleiche, frisch erfasste Aufgabe **WHEN**
  `processPending()` läuft **THEN** übernimmt die zweite Dauer/Kontexte der ersten — die
  Bestandsdaten-Lücke aus der Analyse ist geschlossen.
- **GIVEN** eine Aufgabe mit **beiden** Vermerken (`processedAt != nil` und `rulesAppliedAt != nil`)
  im Store, dazu eine wortgleiche dritte Aufgabe **WHEN** `recognitionInputs(in:)` bzw.
  `processPending()` läuft **THEN** erscheint die erste Aufgabe genau einmal im zusammengeführten
  Pool (kein doppelter Treffer, keine doppelte `Revision` auf der dritten Aufgabe).
- **GIVEN** eine Aufgabe mit `rulesAppliedAt != nil, processedAt == nil` (Regel bereits gelaufen,
  Modell noch nicht) **WHEN** das Modell danach verfügbar wird und `processPending()` erneut läuft
  **THEN** wird die Aufgabe weiterhin im Pending-Fetch gefunden und erhält Titel/Energie/Personen/
  Projekt vom Modell — der Pending-Fetch ist durch `rulesAppliedAt` nicht verengt.
- **GIVEN** eine Aufgabe, deren Regelschritt bereits lief **WHEN** `processPending()` mehrfach läuft
  **THEN** entsteht keine zweite `.duration`-/`.contexts`-Revision — bestätigt, dass AC-8 (#136) und
  AC-8 (#95) durch die Änderung nicht verletzt werden.
- Die bestehenden Tests, die nach einem modellfreien Lauf `processedAt == nil` fordern
  (`EnrichmentTests.swift:255, 286, 570, 636, 670`), bleiben unverändert und grün — sie beweisen,
  dass `processedAt` seine Bedeutung nicht verliert.
- **UI-Smoke-Test** `LooseEndsUITests/RecognitionWalkthroughTests.swift`: Ablauf „erfassen → Dauer
  und Kontext von Hand setzen → wortgleich erneut erfassen → Werte sind in der Detailansicht da" mit
  `--ui-testing` (in-memory Store, echter `FoundationModelsEnricher`, im Simulator praktisch immer
  ohne Apple Intelligence verfügbar — genau der Zielpfad dieser Spec). Screenshots je Schritt als
  Nachweis, nach dem Muster von `CaptureSmokeTests.testPlusButtonProof()`.

### Korpus-Messung als Nulllinie (Ticket-DoD: „Korpus-Messung echt gelaufen")

Die Wiedererkennungs-Regel hat eine eigene Messstrecke gegen die 287 echten Aufgaben:
`LooseEndsTests/RecognitionRuleTests.swift`, Suite `RecognitionRuleCorpusTests` (#136, AC-12), dazu
`RuleLeaveOneOutTests`, `FocusBloxCalibrationTests` und `SelfConsistencyReportTests`. Alle vier
Suiten sind per `.enabled(if: FileManager.default.fileExists(…))` an
`docs/reference/focusblox-corpus.json` gegattert — persönliche, gitignorierte Daten, die in der CI
nie existieren. Der Kommentar in `RecognitionRuleTests.swift:246` sagt es selbst:
**„grün ohne Korpus" heißt „Messung übersprungen", nicht „bestanden".**

Geprüft am 2026-09-28: Die Datei liegt in Hennings Hauptordner
(`/Users/hem/Developer/loose-ends/docs/reference/focusblox-corpus.json`, 200 315 Byte), **nicht** in
diesem Arbeitsstand. Ein Testlauf hier überspringt die Messung also still und sieht trotzdem grün
aus. Daraus folgen zwei verbindliche Schritte:

1. **Vor dem Messlauf** wird der Korpus in diesen Arbeitsstand kopiert (kopiert, nicht verschoben —
   #135 hat gezeigt, dass die Datei sonst exklusiv in einem Arbeitsstand hängt und im Hauptordner
   fehlt). Der Beleg für „echt gelaufen" ist die Anzahl der ausgeführten Tests: mit Korpus liegt sie
   messbar über dem Lauf ohne Korpus, und die Messberichte werden neu geschrieben.
2. **Die erwartete Aussage ist Unveränderlichkeit.** `RecognitionRule` wird von dieser Spec nicht
   angefasst, und die Messung übergibt ihren Pool direkt an `RecognitionRule.match`, ohne
   `EnrichmentCoordinator`. Die Messzahlen müssen deshalb vor und nach der Änderung identisch sein.
   Eine Abweichung wäre ein Befund, kein Fortschritt: Sie hieße, dass die Änderung die reine Regel
   berührt hat, obwohl sie nur ihr Eingangsmaterial betreffen darf.

**Der Beleg wird registriert, nicht behauptet.** Ein Nachweis, den man nur zusichern kann, ist kein
Nachweis — genau dieses Muster hat den Fehler aus #136 überhaupt erst durchgelassen. Der Messlauf
hinterlässt deshalb eine Belegdatei
(`docs/artifacts/fix-144-recognition-pool-empty/korpus-messung.md`) mit:

- der Zahl ausgeführter Tests **ohne** Korpus und **mit** Korpus, je mit Zeitstempel und der
  Commit-Kennung des gemessenen Stands,
- den Namen der vier Suiten, die im zweiten Lauf zusätzlich auftauchen,
- den Messzahlen der Wiedererkennung vor und nach der Änderung, einander gegenübergestellt.

**Die Datei wird aus dem Lauf erzeugt, nicht getippt.** Zeitstempel und Commit-Kennung stammen aus
`date` und `git rev-parse HEAD` zum Zeitpunkt des Laufs, die Testzahlen aus der Zusammenfassungszeile
von `xcodebuild.log` („Test run with N tests …"), die Messzahlen aus den Berichtsdateien, die der Lauf
selbst schreibt. Kein Wert dieser Datei wird von Hand eingetragen — das ist die Bedingung aus
CLAUDE.md („Der Beleg entsteht aus einem echten Lauf … und darf niemals von Hand gesetzt werden").

Diese Datei wird im Workflow als Artefakt registriert, so wie es der Simulator-Nachweis auch wird:

```bash
workflow.py add-artifact test_output \
  docs/artifacts/fix-144-recognition-pool-empty/korpus-messung.md \
  "Korpus-Messung echt gelaufen: Testzahl ohne/mit Korpus, Messzahlen unverändert" phase6_validate
```

Fehlt dieses Artefakt, gilt AC-10 als nicht erfüllt — unabhängig davon, wie der Testlauf aussah.

**Grenze dieses Mechanismus, offen benannt.** `workflow.py add-artifact` prüft nur den Artefakt-Typ
gegen eine feste Liste; Pfad, Beschreibung und Phase werden als Freitext gespeichert, die Datei wird
nicht geöffnet, und das Phasen-Gate zählt nur, dass ein Artefakt der passenden Phase existiert — nicht
was darin steht. Eine inhaltliche Prüfung gibt es dort heute nur für den Adversary-Verdict. Die
Registrierung verkleinert das Loch also (eine echte Datei mit nachvollziehbarer Spur statt eines
Hakens), schließt es aber nicht. Das ist ein Werkzeugmangel, keine Frage dieser Spec: Er gehört zu
**#145, Schnitt 2**, der genau diese Erzwingung für den Simulator-Beleg vorsieht (Prüfsumme gegen den
aktuellen Stand, nicht von Hand setzbar) — dort ist vermerkt, dass Messbelege dieselbe Behandlung
brauchen. Bis dahin trägt die maschinelle Erzeugung oben.

**Nach dem Messlauf** werden die drei Messberichte, die jeder Lauf neu schreibt
(`docs/reference/date-title-fidelity.md` und die Berichte aus #118/#131), auf den Stand vor dem Lauf
zurückgesetzt, bevor die Änderung eingereicht wird — sonst schleppt sie fremde Berichtsänderungen
mit, die nichts mit #144 zu tun haben. (Dieser Arbeitsstand trägt bereits eine solche Änderung an
`docs/reference/date-title-fidelity.md` aus einem früheren Lauf; sie gehört nicht zu #144.)

**Fallstricke, die beim Schreiben zu beachten sind:** Ein `ModelContext` hält seinen
`ModelContainer` nicht selbst am Leben — der Container muss in einer lokalen Variable oder einem
Helfer (`TestStore`) gehalten werden, sonst stürzt der nächste `save`/`fetch`. `SpeechCapture` wird
unter `--ui-testing` übersprungen (`CaptureView.swift:39`), das UI-Testfeld lässt sich also gefahrlos
per `typeText` befüllen.

## Acceptance Criteria

- **AC-1 Wiedererkennung ohne Modell:** Given eine Aufgabe wird ohne Apple Intelligence erfasst,
  Dauer und Kontext vom Nutzer gesetzt, danach eine wortgleiche zweite Aufgabe erfasst / When
  `EnrichmentCoordinator.processPending()` nach beiden Erfassungen läuft / Then trägt die zweite
  Aufgabe dieselbe Dauer und denselben Kontext wie die erste.
- **AC-2 Regel-Vermerk unabhängig vom Modell:** Given drei frisch erfasste Aufgaben ohne verfügbares
  Modell / When `processPending()` läuft / Then tragen alle drei `rulesAppliedAt != nil`, unabhängig
  von `processedAt`.
- **AC-3 Vermerk übersteht einen fehlschlagenden Modellaufruf:** Given ein Enricher, dessen
  `enrich(_:)` wirft / When `processPending()` läuft / Then trägt die betroffene Aufgabe trotzdem
  `rulesAppliedAt != nil`.
- **AC-4 Bestandsdaten bleiben erreichbar:** Given eine Aufgabe mit `processedAt != nil` und
  `rulesAppliedAt == nil` (vor dieser Änderung veredelt) / When eine wortgleiche neue Aufgabe
  verarbeitet wird / Then übernimmt sie Dauer/Kontexte der Bestandsaufgabe.
- **AC-5 Keine doppelten Treffer:** Given eine Aufgabe mit sowohl `processedAt != nil` als auch
  `rulesAppliedAt != nil` / When die Vergleichsmenge gebildet wird / Then erscheint diese Aufgabe
  genau einmal darin.
- **AC-6 Pending-Fetch bleibt unverengt:** Given eine Aufgabe mit `rulesAppliedAt != nil` und
  `processedAt == nil` / When das Modell danach verfügbar ist und `processPending()` erneut läuft /
  Then wird die Aufgabe weiterhin gefunden und erhält Titel/Energie/Personen/Projekt vom Modell.
- **AC-7 Keine doppelte Revision bei wiederholten Regelläufen:** Given eine Aufgabe, deren
  `duration`/`contexts` bereits durch die Regel gesetzt sind / When `processPending()` erneut läuft /
  Then entstehen keine zweiten `.duration`-/`.contexts`-Revisionen.
- **AC-8 Bestehende `processedAt`-Zusagen bleiben unverändert:** Given die Tests
  `EnrichmentTests.swift:255, 286, 570, 636, 670` / When `./scripts/sim.sh unit` läuft / Then bleiben
  sie unverändert und grün.
- **AC-9 Nachweis im Simulator:** Given der `--ui-testing`-Modus mit echtem `FoundationModelsEnricher`
  ohne Apple Intelligence / When der Ablauf „erfassen → Werte setzen → wortgleich erneut erfassen"
  im UI-Test durchläuft / Then zeigt die Detailansicht der zweiten Aufgabe dieselbe Dauer und
  denselben Kontext wie die erste, belegt durch Screenshots.
- **AC-10 Korpus-Messung echt gelaufen und unverändert:** Given `docs/reference/focusblox-corpus.json`
  liegt in diesem Arbeitsstand / When `./scripts/sim.sh unit` läuft / Then werden die vier
  korpusgegatterten Suiten (`RecognitionRuleCorpusTests`, `RuleLeaveOneOutTests`,
  `FocusBloxCalibrationTests`, `SelfConsistencyReportTests`) ausgeführt statt übersprungen — belegt
  durch eine gegenüber dem Lauf ohne Korpus höhere Zahl ausgeführter Tests — und die Messzahlen der
  Wiedererkennung sind mit denen vor der Änderung identisch. Der Beleg liegt als registriertes
  Artefakt vor (`add-artifact test_output`, Pfad und Inhalt siehe „Korpus-Messung als Nulllinie");
  ohne dieses Artefakt gilt AC-10 als nicht erfüllt.

## Risiken

1. **Ein neues `Date?`-Feld auf einem `@Model` ohne `SchemaMigrationPlan`.** Gegenmaßnahme: additiv
   und optional, exaktes Muster von `showInCalendar`/`repeatRule`, die bereits so eingeführt wurden —
   kein neues Migrationsrisiko gegenüber dem Status quo.
2. **Zwei Fetches statt eines belasten den Nachzügler-Lauf zusätzlich.** Gegenmaßnahme: Beide Fetches
   laufen wie bisher genau einmal pro Durchgang, vor der Schleife, nicht pro Aufgabe — die Kostenordnung
   ändert sich nicht.
3. **Die Umformulierung von AC-7 (#136) könnte als Aufweichen des Schutzes missverstanden werden.**
   Gegenmaßnahme: Abschnitt „Implementation Details", Punkt 4, begründet ausführlich, warum der
   Schutzzweck erhalten bleibt (kein KI-Fehler ohne Modell, Nutzerwert-Saatkorn, Guards gegen
   Selbsttreffer) — dieselbe Begründung wird 1:1 in `feat-136-wiedererkennung.md` übernommen.
4. **Der angepasste Test `poolNeverFillsWithoutTheModel` könnte als „Test geschwächt, bis er passt"
   gelesen werden.** Gegenmaßnahme: Die numerische Aussage (`pool.count == 3`) bleibt unverändert,
   nur das Prädikat wechselt vom falschen (`processedAt`) auf das tatsächliche Lesekriterium der
   Vergleichsmenge (`rulesAppliedAt`) — dokumentiert in „Implementation Details", Punkt 5. Dieser
   eine Test prüft allerdings nur das Feld; die Zusammenführung der beiden Vermerke wird erst durch
   die Tests zu AC-4 (Bestandsdaten) und AC-5 (Dedupe) bewiesen. Fehlen die beiden, ist die
   Umstellung tatsächlich eine Abschwächung — sie sind deshalb Pflicht, nicht Beigabe.
5. **Die Korpus-Messung wird still übersprungen, wenn der persönliche Korpus im Arbeitsstand fehlt.**
   Genau dieser Zustand liegt heute vor (Datei nur in Hennings Hauptordner) — ein grüner Lauf würde
   die Messstrecke der Wiedererkennung gar nicht anfassen und das nicht anzeigen. Gegenmaßnahme:
   Abschnitt „Korpus-Messung als Nulllinie" macht das Kopieren zum Pflichtschritt und AC-10 verlangt
   den Beleg über die Zahl ausgeführter Tests statt über die Farbe des Laufs. Der Beleg muss zudem
   als Artefakt registriert sein — ein Gate, das man durch Zusicherung öffnen kann, ist kein Gate.

## Alternativen

- **Alternative 1 — `processedAt` erst nach dem Regelschritt setzen (statt nur nach dem
  Modellschritt):** verworfen. Bricht sechs Tests hart
  (`EnrichmentTests.swift:181, 255, 284/285, 570, 636, 670`) und widerspricht ADR-4 sowie #95
  AC-7/AC-8 wörtlich. Vor allem: Der Nachzügler-Fetch ist `processedAt == nil && statusRaw ==
  unprocessed` — würde `processedAt` ohne Modell gesetzt, bekäme eine ohne Apple Intelligence
  erfasste Aufgabe **nie mehr** Titel, Energie, Personen oder Projekt, auch wenn das Modell später
  verfügbar wird. Genau dieses Problem hat #95 bewusst gelöst; Alternative 1 führt es wieder ein.
- **Alternative 2 — eigener Vermerk `rulesAppliedAt` (gewählt):** Bricht keinen der 226 bestehenden
  Tests, schließt beide Fehlerpfade (kein Modell, fehlgeschlagener Modellaufruf) zugleich und ist die
  einzige Alternative, die „Rules before the model" wörtlich umsetzt — der Regelpfad bekommt seinen
  eigenen Zustand statt beim Modell mitzumieten. Die Bestandsdaten-Lücke (Aufgaben mit `processedAt`
  aber ohne `rulesAppliedAt`) wird durch die Zwei-Fetch-Zusammenführung geschlossen, nicht durch eine
  Datenmigration.
- **Alternative 3 — Pool über „hat einen gesetzten Wert mit Herkunft" statt über einen Zeitstempel:**
  verworfen. Bricht den bestehenden Test „Zwei unverarbeitete Aufgaben im selben Lauf befruchten sich
  nicht" (`EnrichmentTests.swift:538-554`, AC-7 aus #136) direkt: Eine Aufgabe mit nutzergesetzter
  Dauer wäre sofort im Pool, auch ohne dass ihr eigener Regel- oder Modelllauf je stattfand. Würde die
  Zusage aus der #136-Spec inhaltlich kippen, nicht nur umformulieren — eine größere Spec-Änderung mit
  eigener Begründungspflicht, sachlich vertretbar, aber hier nicht gewählt, weil Alternative 2 dieselbe
  Wirkung ohne Zusagenbruch erreicht.
- **Alternative 4 — Pool = alle Aufgaben außer denen des laufenden Durchgangs (kein neues Feld, keine
  Migration):** geprüft und widerlegt. Ohne Modell bleibt `status` dauerhaft `.unprocessed` (nur
  `EnrichmentWriter` setzt ihn), die erste Aufgabe stünde also bei **jedem** künftigen Durchgang
  wieder im Pending-Fetch und wäre damit strukturell immer von der Vergleichsmenge ausgeschlossen.
  Der eigentliche Fehler (Pool bleibt leer) bliebe bestehen.

## Definition of Done

- [ ] AC-1 bis AC-10 erfüllt, belegt durch die im Test Plan genannten Tests
- [ ] `./scripts/sim.sh unit` grün, inklusive der beiden bereits committeten RED-Tests aus
      `RecognitionPoolReachabilityTests`
- [ ] Korpus-Messung **echt gelaufen**, nicht übersprungen: `docs/reference/focusblox-corpus.json` lag
      im Arbeitsstand, die vier gegatterten Suiten wurden ausgeführt, die Messzahlen der
      Wiedererkennung sind unverändert
- [ ] Der Messbeleg ist als Artefakt registriert (`add-artifact test_output`, Belegdatei mit Testzahl
      ohne/mit Korpus und den gegenübergestellten Messzahlen) — ein nur zugesicherter Messlauf zählt
      nicht
- [ ] Die drei Messberichte, die jeder Lauf überschreibt, auf den Stand vor dem Lauf zurückgesetzt —
      die Änderung schleppt keine fremden Berichtsänderungen mit
- [ ] Build erfolgreich (`./scripts/sim.sh build` ohne Errors), jeder Commit kompiliert
- [ ] Drei Abnahmestufen durchlaufen: Tests → Simulator → Hennings iPhone 16 Pro
      (`./scripts/sim.sh device`) — kein Schritt entfällt, TestFlight ist kein Ersatz dafür
- [ ] Simulator-Durchlauf als Artefakt registriert (Screenshots aus `RecognitionWalkthroughTests`),
      weil die Gate-Mechanik aus #145 noch nicht existiert und der Nachweis nicht der Disziplin
      überlassen werden darf
- [ ] ADR-4 (`docs/project/00-entscheidungen.md`) um den Satz zu `rulesAppliedAt` ergänzt
- [ ] `docs/specs/enrichment/feat-136-wiedererkennung.md` AC-7 umformuliert und Implementierungsnotiz
      zur Vergleichsmenge nachgezogen
- [ ] Nach dem Zusammenführen: Hennings Hauptordner nachgezogen und Projekt neu erzeugt
      (`bash ~/.claude/scripts/loose-ends-sync-main.sh`)
- [ ] PR schließt #144 (`Closes #144`)
- [ ] Kein manueller Testhinweis an Henning — jede Acceptance Criterion ist automatisiert bewiesen
- [ ] CI grün

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** ADR-4 (Ergänzung, keine neue Nummer)
- **Rationale:** Die Änderung bewegt sich innerhalb der bestehenden Entscheidung „Veredelung genau
  einmal" und präzisiert sie, statt sie zu ersetzen. Ergänzungssatz für
  `docs/project/00-entscheidungen.md`, direkt im Anschluss an den bestehenden Text zu ADR-4 (Z. 92):
  „Seit #144 markiert `rulesAppliedAt` unabhängig davon, ob das Modell verfügbar war oder der
  Modellaufruf glückte, dass der Regelschritt (Fälligkeitsdatum, Wichtigkeit, Dringlichkeit,
  Wiedererkennung) für diese Aufgabe gelaufen ist; die Vergleichsmenge der Wiedererkennung
  (`RecognitionRule`) liest `processedAt` und `rulesAppliedAt` gemeinsam, damit sie nicht am
  Modell hängt." Kein neuer Architekturbaustein: `rulesAppliedAt` ist ein weiteres Feld nach dem
  Muster von `processedAt` selbst, keine neue Schicht oder Komponente.

## Changelog

- 2026-09-28: Spec aus der Analyse-Zusammenfassung (Phase 2, #144) erstellt.
- 2026-09-28: Nach unabhängigem PO-Briefing ergänzt — der Abnahmepunkt „Korpus-Messung echt gelaufen"
  aus dem Ticket fehlte vollständig. Neu: Abschnitt „Korpus-Messung als Nulllinie" im Test Plan,
  AC-10, zwei Punkte in der Abnahmeliste und Risiko 5 (stiller Übersprung bei fehlendem Korpus).
  Risiko 4 um den Hinweis ergänzt, dass die Testumstellung ohne die Tests zu AC-4 und AC-5 doch eine
  Abschwächung wäre.
- 2026-09-28: Zweite Briefing-Runde — der Messbeleg war zwar inhaltlich definiert, aber an keinen
  Mechanismus gebunden und damit durch Zusicherung erfüllbar. Neu: Belegdatei
  `docs/artifacts/fix-144-recognition-pool-empty/korpus-messung.md`, Registrierung per
  `add-artifact test_output` als Bedingung für AC-10, entsprechender Punkt in der Abnahmeliste.
  Damit ist die Auflage des Briefings in der Spec verankert statt der Umsetzung überlassen.
- 2026-09-28: Dritte Briefing-Runde — das Registrierwerkzeug prüft Artefakt-Inhalte nicht, die
  Registrierung allein erzwingt also keine Wahrheit. Neu: Die Belegdatei wird maschinell aus dem Lauf
  erzeugt (Zeitstempel, `git rev-parse HEAD`, Testzahlen aus `xcodebuild.log`), kein Wert von Hand.
  Die verbleibende Werkzeuglücke ist in der Spec offen benannt und als Befund an #145 (Schnitt 2)
  angehängt, wo die Erzwingung hingehört — sie ist ausdrücklich nicht Teil von #144.
