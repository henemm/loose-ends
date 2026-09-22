# Adversary-Dialog: Spike #108 — Selbstkonsistenz-Signal

Geprüft gegen `docs/specs/measurement/spike-108-selbstkonsistenz-signal.md` (AC-1 bis AC-9).
Kontextisoliert: nur Spec gelesen, Beweise selbst über Bash/Read gegen den Code und den
vorhandenen grünen Testlauf erbracht (kein Zugriff auf den Implementierer).

### Runde 1 — Oberflächliche Prüfung: existiert Code und Test je AC?

- [x] AC-1: `Measurement/Corpus.swift:45-49,60` — fünf neue optionale `*Truth`-Felder in
  `Corpus.Entry`, additiv in `CodingKeys`. Tests `CorpusTests.focusBloxTruthFieldsDecode` und
  `focusBloxTruthFieldsDefaultToNilForDateTitleCorpus` (Zeilen 174-193) — beide "passed" im Log
  (`test-green-output.txt:1245-1248`).
- [x] AC-2: `Measurement/MeasurementRun.swift:35-39,65-92` — fünf neue Felder mit
  `decodeIfPresent`/Default. Tests `oldResultWithoutSelfConsistencyFieldsDecodes`,
  `selfConsistencyFieldsRoundTrip` (`MeasurementRunTests.swift:150-185`) — "passed"
  (`test-green-output.txt:1435-1438`).
- [x] AC-3: `Shared/Enrichment/EnrichmentDraft.swift:34-38` (`selfConsistencyValues`),
  `LooseEndsLab/MeasurementRunner.swift:141-151` (genau ein `enrich`-Aufruf, danach reines
  Auslesen). Tests `draftSelfConsistencyValuesPassThrough`,
  `draftSelfConsistencyValuesWithMissingGuesses` (`MeasurementRunTests.swift:187-212`) — "passed"
  (`test-green-output.txt:1439-1442`).
- [x] AC-4: `Measurement/Corpus.swift:143-149` (`runsPerEntry(from:flag:)`),
  `LooseEndsLab/LabApp.swift:13-15` (verdrahtet). Test `runsPerEntryFromArguments`
  (`CorpusTests.swift:199-203`) — "passed" (`test-green-output.txt:1249-1250`).
- [x] AC-5: `Measurement/SelfConsistency.swift:16-25` (`majority`/`agreement`). Test
  `majorityAndAgreementForSingleValueField` — "passed" (`test-green-output.txt:1493-1494`).
- [x] AC-6: `Measurement/SelfConsistency.swift:31-38` (`majoritySet`/`agreementSet`). Tests
  `majorityAndAgreementForSetField`, `setMajorityMustMatchTruthExactly` — "passed"
  (`test-green-output.txt:1495-1498`).
- [x] AC-7: `Measurement/SelfConsistency.swift:66-83` (`table(field:outcomes:)`). Test
  `tableComputesCoverageAndHitRate` — "passed" (`test-green-output.txt:1499-1500`).
- [x] AC-8: `scripts/export-focusblox-corpus.swift:45-51,214-221` — neue Felder additiv gesetzt.
  Kein Testziel (Spec akzeptiert das explizit, RED-Beleg dokumentiert die Einschränkung als vor
  Freigabe genannt und akzeptiert, `test-red-output.txt:86-92`).
- [x] AC-9: `LooseEndsTests/SelfConsistencyReportTests.swift` komplett gelesen — gated Suite,
  liest zwei lokale JSON-Dateien, kein Modellaufruf. Suite korrekt "skipped" im grünen Lauf
  (`test-green-output.txt:1490-1491`), weil die beiden Dateien in diesem Repo fehlen.

Erster Eindruck: alle neun Punkte scheinen durch Code + Test belegt. Zu oberflächlich — Runde 2
sucht gezielt nach Lücken, die ein einzelner grüner Test verdecken könnte.

### Runde 2 — Gezielte Kantenfall- und Lücken-Suche

1. **AC-2 Rückwärtskompatibilität vollständig?** Geprüft, ob `MeasurementResult` einen manuellen
   `encode(to:)` braucht, weil `init(from:)` manuell ist. Ergebnis: keine manuelle
   `encode(to:)`-Methode im Typ vorhanden; Swift synthetisiert `Encodable` unabhängig von einem
   handgeschriebenen `Decodable.init(from:)`, solange die `CodingKeys` zu den gespeicherten
   Eigenschaften passen (`MeasurementRun.swift:65-69` deckt alle Felder ab). Der
   Round-Trip-Test (`selfConsistencyFieldsRoundTrip`) beweist das zusätzlich empirisch — "passed".
   Kein Defekt.
2. **AC-3 "kein zweiter Modellaufruf" — nur behauptet oder durch Code belegt?** In
   `MeasurementRunner.swift:129-160` steht genau ein `try await enricher.enrich(input)`
   (Zeile 141); alle fünf neuen Felder werden danach aus der bereits vorliegenden `draft`
   gelesen (`selfConsistencyValues`, Zeile 146). Kein zweiter Aufruf im Code. Die Testabdeckung
   für `selfConsistencyValues` selbst (statt `measure(:runIndex:)` direkt) ist eine im Spec-Text
   selbst dokumentierte, begründete Abweichung (Nachtrag RED-Phase: `measure` ist `private`,
   importiert `UIKit`, nur `platform: iOS`, am Mac nicht direkt testbar) — keine Lücke, sondern
   eine von der Spec selbst vorweggenommene Einschränkung.
3. **AC-6 Teiltreffer wirklich ausgeschlossen?** `agreementSet`/`majoritySet` vergleichen
   `Set<String>` exakt (`SelfConsistency.swift:31-38`); der Report-Test vergleicht
   `majority == Set(expected)` (`SelfConsistencyReportTests.swift:51`) — keine Jaccard/F1-Toleranz
   irgendwo im Pfad. Bestätigt exakte Mengengleichheit ohne Teiltreffer, wie AC-6 verlangt.
4. **Raw-Value-Kompatibilität zwischen Modell-Antwort und Wahrheit.** Geprüft, ob
   `EnrichmentDraft.selfConsistencyValues` (`.rawValue` von `Importance`/`Urgency`/
   `DurationBucket`/`Energy`) dieselben String-Literale liefert wie der Export-Mapper
   (`mapImportance`/`mapUrgency`/`mapDurationBucket`/`mapEnergy` in
   `scripts/export-focusblox-corpus.swift:83-114`). Enum-Rohwerte in
   `Shared/Models/Enums.swift:21-27` (`low`/`medium`/`high`,
   `minutes5`/`minutes15`/`minutes30`/`hour1`/`hours2plus`) stimmen exakt mit den vom Skript
   geschriebenen Strings überein. Ohne diese Übereinstimmung wäre `majority == expected` in
   `SelfConsistencyReportTests.swift:36` und die Trefferquote in AC-7 strukturell falsch (ein
   stiller Fehlschlag, der nie einen Absturz, nur falsche Zahlen produziert hätte). Kein
   Mismatch gefunden.
5. **AC-8 wirklich additiv, keine Werteänderung an bestehenden Schlüsseln?** `git diff main --
   scripts/export-focusblox-corpus.swift` gelesen: `rawText`/`title`/`contexts`/`importance`/
   `urgency`/`durationBucket`/`energy`/`dueDate`/`capturedAt`/`completedAt`/`blockedBy`/
   `isCompleted`/`repeatRule` behalten exakt dieselben Zuweisungen wie vor dem Schnitt (nur in
   lokale `let`s vorgezogen, keine Werteänderung). `text` ist wortwörtlich `title` — identisch zu
   `rawText`, das ebenfalls `title` ist (AC-8-Wortlaut "text identisch zu rawText" erfüllt durch
   Konstruktion, nicht nur durch Zufall gleicher Werte). Kein Defekt.
6. **AC-9 Gate wirklich sicher — läuft nie in CI?** `@Suite(.enabled(if:))` prüft
   `FileManager.default.fileExists` für zwei gitignored, personenbezogene Pfade unter
   `docs/reference/`. In CI (frischer Checkout) existieren beide Dateien nicht → Suite deaktiviert.
   Bestätigt durch den lokalen grünen Lauf selbst: Suite lief hier ebenfalls nicht (Dateien fehlen
   auch im Worktree), exakt das erwartete Verhalten laut Spec. Kein Modellaufruf im Testkörper
   gefunden (nur `SelfConsistency.majority`/`table`, reine In-Memory-Berechnung über zwei bereits
   geladene JSON-Dateien).
7. **Regression: `selfConsistencyValues` von Produktcode aufgerufen?** `grep -rn
   "selfConsistencyValues"` über das gesamte Repo: nur `MeasurementRunner.swift` (Messcode) und
   zwei Testfälle. Kein Aufruf aus `EnrichmentWriter`, `EnrichmentCoordinator` oder einer View.
   Bestätigt die ADR-Aussage "No product code calls it" (`EnrichmentDraft.swift:33`).
8. **Regression: bestehende `MeasurementResult`/`Corpus.Entry`-Initialisierer gebrochen?** Alle
   neuen Parameter tragen Defaultwerte (`nil`/`[]`); `git diff` zeigt reine Ergänzung, keine
   Streichung oder Umbenennung bestehender Parameter. Der volle grüne Lauf (150 Tests, 0
   Fehlschläge, `test-green-output.txt` letzte Zeile) deckt u. a. `DateParserCorpusTests`,
   `EnrichmentTests`, `DateTitleReportTests` ab — alle unverändert grün.
9. **`people`/`project` wirklich nicht erweitert?** `grep -n "projectTruth" Measurement/*.swift`
   — kein Treffer. `MeasurementResult.people` unverändert (`MeasurementRun.swift:24`, nicht in
   diesem Schnitt geändert). Entspricht dem expliziten Ausschluss im Spec-Abschnitt "Nicht in
   diesem Schnitt".

Keine der neun Kantenfall-Prüfungen deckt einen Defekt auf. Alle neun AC sind sowohl durch
automatisierten Testlauf (wo möglich) als auch durch direktes Lesen von Code und Diff belegt.

## Verdict

VERDICT: VERIFIED
