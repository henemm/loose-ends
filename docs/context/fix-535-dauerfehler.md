# Context: fix-535-dauerfehler

## Request Summary
Epic #563, Unterticket #535: Ein Modellaufruf, der dauerhaft scheitert (Guardrail, Kontextfenster), darf die Aufgabe
nicht bei jedem App-Start und jeder Erfassung erneut ans Modell schicken. Vorübergehende Fehler bleiben wie heute.
Es hat nie anders funktioniert: Die Lücke besteht seit #530, kein Rückschritt.

## Befund im Code (Ist-Zustand)
- `EnrichmentCoordinator.processPending` fängt jeden Fehler von `callModel` in einem `catch`, loggt ihn und lässt
  `processedAt` leer. Die Auswahl der nächsten Läufe ist `processedAt == nil` (zwei Fetches, Status
  `unprocessed` und `active` ohne Elternaufgabe). Darum geht jede gescheiterte Notiz bei jedem Durchlauf erneut ans Modell.
- `processedAt` wird im Produktpfad nur in `EnrichmentWriter.apply` gesetzt (am Ende, nach den Feldern).
- `rulesAppliedAt` wird für jede Aufgabe im Durchlauf gesetzt, unabhängig vom Modell (#144). Die Regeln laufen also auch bei Dauerfehlern.
- `reanalyze` (Menü „Neu analysieren“, ADR-4) hat keinen `processedAt`-Zugriff und bleibt der ausdrückliche zweite Versuch.
  Sein Fehlerfall liefert `finished(changed: 0, modelRan: false)`.
- Aufrufer von `processPending`: `ContentView` (Szenenwechsel auf aktiv, nach Erfassung, Zeile 226), `MenuBarCapture` (Mac, nach Speichern).

## Related Files
| File | Relevance |
|------|-----------|
| `Shared/Enrichment/EnrichmentCoordinator.swift` | Das `catch` in `processPending` (Zeile ~92) ist die Stelle; `callModel`, `ModelDeadline`-Timeout läuft dort hinein. Geräteliste Stufe 3. |
| `Shared/Enrichment/EnrichmentWriter.swift` | Setzt `processedAt` (Zeile 96) zusammen mit den KI-Revisionen; für Dauerfehler ohne Revision zu setzen. |
| `Shared/Enrichment/ModelDeadline.swift` | `ModelDeadline.Exceeded` ist die Zeitgrenze: vorübergehend. |
| `Measurement/MeasurementRun.swift` | `MeasurementErrorKind.classify` (seit #536 auf `LanguageModelError`) ordnet Fehler in Textarten. Wird **nicht** in die App übersetzt (nur `LooseEndsTests` und Labor-App), taugt daher nur als Vorlage. |
| `Shared/Enrichment/EnrichmentDraft.swift` | `TaskEnricher`-Protokoll (`enrich` wirft beliebige Fehler). |
| `Shared/Enrichment/FoundationModelsEnricher.swift` | Wirft die SDK-Fehler unverändert durch. `#if canImport(FoundationModels) && !os(watchOS)`. |
| `LooseEndsTests/EnrichmentTests.swift` | `StubEnricher` (Fehler, Verzögerung, Antwort je Notiz), `StubFailure`. |
| `LooseEndsTests/ModelSeamTests.swift` | Test `guardrailRefusal` (Zeile ~98) hält heute `processedAt == nil` fest, **dreht sich um**. Zeitgrenze- und Refusal-Tests als Muster. |
| `LooseEndsTests/ReanalysisTests.swift` | Fehlerfall von `reanalyze` bleibt unverändert. |
| `docs/project/00-entscheidungen.md` | ADR-4: Satz zu `processedAt` bei Dauerfehler ergänzen. |
| `Shared/Models/TaskItem.swift`, `cloudkit/schema.ckdb` | Feld `processedAt` existiert (CD_processedAt). **Kein neues Feld nötig, keine Schema-Arbeit.** |

## Existing Patterns
- Fehler bleiben bei der einen Aufgabe, der Durchlauf läuft weiter, nichts wird still verschluckt (Koordinator-Kommentar, `Logger`).
- Reine Regeln als eigene Dateien in `Shared/Enrichment` mit Unit-Tests (z. B. `DueDateRule`); Fehlerarten als kleine Aufzählung mit statischem `classify` (`MeasurementErrorKind`).
- Modellfehler im Test: `StubEnricher(failure: LanguageModelError.guardrailViolation(.init(debugDescription:)))` unter `#if canImport(FoundationModels) && !os(watchOS)`.
- Messcode und Produktcode getrennt: `Measurement/` hat kein `import LooseEnds`.

## Dependencies
- Upstream: `LanguageModelError` (iOS 27 SDK; Fälle laut `MeasurementErrorKind.classify`: rateLimited, guardrailViolation, contextSizeExceeded, refusal, timeout, unsupportedCapability, unsupportedTranscriptContent, unsupportedGenerationGuide, unsupportedLanguageOrLocale), `SystemLanguageModel.Error.assetsUnavailable`, `LanguageModelSession.Error` (concurrentRequests, transcriptMutationWhileResponding), `GeneratedContent.ParsingError`.
- Downstream: Wiedererkennungs-Pool liest `processedAt != nil` **oder** `rulesAppliedAt != nil`. Letzteres ist für die Aufgabe ohnehin gesetzt, der Pool ändert sich also nicht. Keine Ansicht liest `processedAt` (grep über `LooseEnds/` und `Shared/` außerhalb der Anreicherung: nur Kommentare).

## Existing Specs
- `docs/specs/enrichment/fix-144-recognition-pool-empty.md` (Marker `rulesAppliedAt` neben `processedAt`)
- `docs/specs/enrichment/feat-95-parser-in-app.md`, `feat-136-wiedererkennung.md`
- Vorgänger im Epic: #530 (Naht, PR #532), #536 (Fehlerarten, PR #579, gemergt 2026-10-20)

## Risks & Considerations
- **Bedeutung von `processedAt` ändert sich leicht:** bisher „Modell hat die Aufgabe verarbeitet“, künftig auch „Modell hat sie endgültig abgelehnt“, ohne KI-Revision. ADR-4 und der Kommentar am Feld müssen das sagen. Alternative ohne Bedeutungswechsel wäre ein neues Feld (CloudKit-Schema, additiv, Production-Deploy durch Henning) oder ein Fehlversuchszähler; beides schwerer als das Ticket verlangt, in der Analyse gegenüberstellen.
- **Einteilung ist die eigentliche Entscheidung.** Klar dauerhaft: Guardrail, Kontextfenster. Klar vorübergehend: Zeitgrenze, Rate-Limit, Modell-Assets fehlen, gleichzeitige Anfrage, Gerät gesperrt. Offen: `refusal`, die `unsupported…`-Fälle (Sprache/Locale kann sich mit der Systemeinstellung ändern), Dekodierfehler (`ParsingError`, nicht deterministisch). Unbekannte Fehler (`@unknown default`, fremde Typen) im Zweifel vorübergehend, damit nichts Wiederholbares verloren geht.
- **Klassifikation gehört in den Produktpfad** (`Shared/Enrichment`), nicht in `Measurement/`. Datei muss watchOS-sicher bleiben (`#if canImport(FoundationModels) && !os(watchOS)`), `Shared/` kompiliert in Watch und Widgets mit.
- **Testbarkeit der Fälle:** Nur `guardrailViolation(.init(debugDescription:))` ist im Repo schon konstruiert. Ob `contextSizeExceeded`, `refusal` usw. in Tests ohne Modell gebaut werden können, ist im SDK zu prüfen (konnte hier wegen einer Hook-Sperre für berechnete Pfade nicht nachgesehen werden). Fällt das aus, braucht die Klassifikation einen testbaren Zwischenschritt.
- **Bestehender Test dreht sich um:** `guardrailRefusal` erwartet heute `processedAt == nil`; unter #535 erwartet er ein gesetztes `processedAt` ohne Revision, mit gesetztem `rulesAppliedAt`.
- **Wiederholung bleibt möglich:** „Neu analysieren“ läuft unverändert; ob das Detail nach einem Dauerfehler etwas anzeigt, ist nicht Teil des Tickets (neues Ticket, falls gewünscht).
- **Stufe 3:** `EnrichmentCoordinator.swift` steht auf der Geräteliste. Nachweis läuft über TestFlight (Henning, 2026-10-10), nicht über das Gerät vorher; nichts auf Hennings Geräten ohne sein „jetzt ist ein Test möglich“.
- **Scoping:** voraussichtlich 4 Dateien (Koordinator, neue Klassifikationsdatei, ModelSeamTests, ADR-4), etwa 100 Zeilen; Messcode bleibt unangetastet.
- **Alternative zum Ticket (Regeln vor Modell, Alternativen):** Statt Fehlerart einen Zähler je Aufgabe (nach drei Fehlversuchen gilt es als dauerhaft). Braucht ein neues Feld, trennt aber ohne SDK-Wissen und fängt auch unbekannte Dauerfehler. Gegenargument: ein vorübergehender Fehler (Gerät gesperrt) würde die Aufgabe nach drei Starts fälschlich ausschließen.

## Analysis

### Type
Bugfix (Lücke seit #530, kein Rückschritt). Die Regel „Ohne Modell geht es nicht, weil …“ greift nicht: das Ticket gibt dem Modell kein neues Feld, es hält das Modell im Gegenteil aus.

### Recherche (Pflicht vor Analyse)
- Apple-Doku/Forum: Guardrail = Eingabe vom System als heikel eingestuft, Umformulieren hilft, Wiederholen derselben Eingabe nicht (Apple DTS im Forum, https://developer.apple.com/forums/thread/792076). Kontextfenster: hängt an Eingabelänge; Apple-Doku `exceededContextWindowSize` (iOS 26–27).
- Ein Blogbericht (https://drobinin.com/consulting/foundation-models-apple-intelligence/putting-apple-foundation-models-in-a-real-app/) behandelt Guardrail und nicht unterstützte Sprache als nicht wiederholbar, Kontextüberlauf als behebbar (Sitzung neu bauen). Unbestätigt: „iOS 26.4 senkt Guardrail-Fehlalarme“ (WWDC 2026) — spricht dafür, ein Dauerfehler-Merkmal nicht endgültig zu behandeln.
- SDK: Alle Fälle von `LanguageModelError` sind in Tests ohne Modell baubar (`MeasurementRunTests.swift:73–78` konstruiert rateLimited, guardrail, contextSize, refusal, timeout, unsupported). Das offene Risiko aus der Kontextsammlung ist damit geklärt.

### Reproduktion (Pflicht)
Wird in der TDD-Phase am Koordinator gefahren: `StubEnricher` wirft `guardrailViolation`; zwei `processPending`-Läufe nacheinander. Heute: `callCount == 2`, `processedAt == nil` (der vorhandene Test `guardrailRefusal` hält nur das erste fest). Rot-Beleg = Zähler 2 statt 1. Der Weg ist der des Produkts (derselbe Koordinator wie in `ContentView`), keine zweite Implementierung.

### Root Cause
`EnrichmentCoordinator.processPending`: das `catch` um `callModel` unterscheidet nicht nach Fehlerart und lässt `processedAt` leer. Auswahl der Kandidaten ist `processedAt == nil` → jede gescheiterte Notiz geht bei jedem Szenenwechsel und jeder Erfassung erneut ans Modell. Stelle: Zeilen ~88–92.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Shared/Enrichment/ModelFailure.swift` | CREATE | Reine Einteilung `isPermanent(_ error:)`; `#if canImport(FoundationModels) && !os(watchOS)`, sonst immer vorübergehend |
| `Shared/Enrichment/EnrichmentCoordinator.swift` | MODIFY | Im `catch`: bei Dauerfehler `task.processedAt = Date()` ohne Revision, Log `notice` mit Fehlerart |
| `LooseEndsTests/ModelSeamTests.swift` | MODIFY | `guardrailRefusal` dreht sich um; neu: Kontextfenster dauerhaft, Timeout/Rate-Limit/Assets/unbekannt vorübergehend (zweiter Lauf ruft erneut), „Neu analysieren“ nach Dauerfehler ruft das Modell trotzdem |
| `LooseEndsTests/ModelFailureTests.swift` | CREATE | Einteilung je Fehlerfall, ohne Koordinator |
| `docs/project/00-entscheidungen.md` | MODIFY | ADR-4: `processedAt` heißt auch „Modell hat endgültig abgelehnt“ |

`Shared/Models/TaskItem.swift` bekommt höchstens einen Kommentar am Feld (5. Datei); kein neues Feld, **keine CloudKit-Schema-Arbeit**.

### Scope Assessment
- Files: 5–6 (Grenze 4–5: Kommentar am Feld in die ADR/Koordinator-Doku legen, dann 5)
- Estimated LoC: +~120/−~10
- Risk Level: LOW–MEDIUM (zentraler Durchlauf, aber ein Zweig im `catch`)

### Einteilung (die eigentliche Entscheidung)
| Fehler | Einstufung | Grund |
|---|---|---|
| `guardrailViolation` | dauerhaft | Ticket; Eingabe ändert sich nicht |
| `contextSizeExceeded` | dauerhaft | Ticket; Notiztext ändert sich nicht |
| `timeout`, `ModelDeadline.Exceeded`, `rateLimited` | vorübergehend | Ticket |
| `assetsUnavailable`, `concurrentRequests`, `transcriptMutation…` | vorübergehend | Zustand des Geräts |
| `refusal` | vorübergehend | Modell lehnt je nach Lauf unterschiedlich ab; nicht gemessen, im Zweifel Wiederholung |
| `unsupported…` (Sprache, Guide, Capability) | vorübergehend | Systemsprache/OS kann sich ändern |
| `ParsingError`, `@unknown default`, fremde Typen | vorübergehend | nichts Wiederholbares verlieren |

### Technical Approach (Empfehlung)
Regel statt Zähler: eine reine Funktion ordnet den Fehler ein (kein Modell, keine Heuristik über Text). Im Koordinator-`catch` bei „dauerhaft“ `processedAt = Date()`, keine `Revision`, `rulesAppliedAt` ist ohnehin gesetzt. `reanalyze` bleibt unverändert (ADR-4: ausdrücklicher zweiter Versuch). Die Klassifikation wird bewusst **nicht** aus `Measurement/` übernommen (dort nicht im App-Ziel; der Messcode bleibt unangetastet).

### Alternativen
1. **Fehlversuchszähler je Aufgabe** (3 Versuche): fängt auch unbekannte Dauerfehler, braucht aber ein neues Feld (CloudKit-Schema, Production-Deploy durch Henning) und schließt vorübergehende Fehler (gesperrtes Gerät) nach drei Starts fälschlich aus. Kippt keine ADR, aber die Zusage „Schema möglichst selten anfassen“. Verworfen.
2. **Fehlerart + OS-Version merken**, nach OS-Update erneut versuchen (wegen möglicher Guardrail-Änderungen): sauberer, aber neues Feld, schwerer als das Ticket. Als Folgeticket nur, falls nach einem OS-Update Notizen auffallen, die „zu Unrecht“ stehenbleiben; Abhilfe bis dahin: „Neu analysieren“.
3. **Nichts tun, nur Log**: kostet bei jedem Start einen Modellaufruf je gesperrter Notiz. Verworfen.
Gekippte ADR: keine; ADR-4 wird um einen Satz ergänzt.

### Befunde gegen den Plan
- `processedAt` ändert seine Bedeutung leicht („verarbeitet“ → „abschließend bearbeitet“); gelesen wird es nur vom Koordinator und vom Wiedererkennungs-Pool, der ohnehin `rulesAppliedAt` mitprüft → keine Wirkung auf Ansichten (grep belegt).
- Ein einmal gesetzter Dauerfehler bleibt über OS-Updates stehen (siehe Alternative 2). Hinnehmbar, Abhilfe vorhanden.
- Dauerfehler ist für den Nutzer unsichtbar (kein Hinweis im Detail). Nicht Teil des Tickets; bei Wunsch neues Ticket.

### Dependencies
`LanguageModelError`, `SystemLanguageModel.Error`, `LanguageModelSession.Error` (iOS-27-SDK, nur unter `canImport`). Aufrufer `ContentView` und `MenuBarCapture` unverändert.

### Stufe 3
`EnrichmentCoordinator.swift` steht auf der Geräteliste: Nachweis über TestFlight nach Merge (Henning, 2026-10-10), nichts auf seinen Geräten ohne „jetzt ist ein Test möglich“. Simulator: `--ui-testing` schaltet das Modell ab, der echte Fehlerzweig ist dort nur über Unit-Tests mit `StubEnricher` erreichbar.

### Open Questions
- [ ] Keine für Henning (rein technisch). `refusal` bleibt vorübergehend, bis jemand ein deterministisches Verhalten misst.
