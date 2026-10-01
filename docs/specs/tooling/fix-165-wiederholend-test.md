---
entity_id: fix-165-wiederholend-test
type: bugfix
created: 2026-10-01
updated: 2026-10-01
status: draft
workflow: bug-165-wiederholend-test
---

# Spec: UI-Test „wiederholende Aufgabe löschen“ läuft lokal und in der CI beim ersten Versuch (#165)

## Approval

- [ ] Approved

## Purpose

`CaptureSmokeTests/testDeletingRecurringTaskAfterCompletionDoesNotCrash` (Regressionstest für #121)
ist lokal mit aktivem Modell und in der CI ohne Modell beim ersten Versuch grün. Damit lässt sich die
Klasse `CaptureSmokeTests` mit `./scripts/sim.sh test-proof` (#145) belegen, und der Wiederholungslauf
der CI (`-retry-tests-on-failure`) verdeckt diesen Test nicht mehr.

Kein App-Fehler, beide Ursachen liegen im Testaufbau (Analyse: `docs/context/bug-165-wiederholend-test.md`).

Regeln vor Modell: nicht einschlägig. Es wird kein Modellfeld abgeleitet, nur ein Testaufbau repariert.

## Source

- **Datei:** `LooseEndsUITests/CaptureSmokeTests.swift`
  - `openMenu` (Zeile 32-42): erkennt künftig, wenn das Drücken ins Detail navigiert hat
  - `testDeletingRecurringTaskAfterCompletionDoesNotCrash` (ab ca. Zeile 300): sucht die Aufgabe nach
    dem Setzen von „Daily“ über „Repeating“ und die Kennung `taskRow_*`
- **Datei:** `docs/project/04-stand.md` — geschlossene #20, #21, #74 aus der Prioritätsliste entfernen

### Ursachenkette

1. **Lokal (Zeile 336, „Should be back at the list with the task visible“):** Der Simulator nutzt die
   Apple Intelligence des Macs, das Modell läuft also auch im UI-Test. `EnrichmentWriter.apply` setzt bei
   gesetztem Titel `status = .active` (`Shared/Enrichment/EnrichmentWriter.swift:34`). Beim Rücksprung
   aus dem Wiederholungs-Editor feuert `TaskDetailView.onAppear` erneut, `markSeen()` quittiert die
   KI-Revisionen (`LooseEnds/Views/TaskDetailView.swift:96-98, 165-168`). Danach greift keine Bedingung
   von „New“ mehr (`Shared/Models/ViewRules.swift:16`), die Aufgabe verlässt die Ansicht und die Liste ist
   leer. Das ist gewolltes Produktverhalten. Der Test setzt stillschweigend „kein Modell“ voraus
   (`CaptureSmokeTests.swift:334-336`: Suche der Zeile in „New“ über den Titel).
2. **CI (Zeile 341, „Long press should open the menu with Complete“):** Auf dem langsamen Runner kommt
   `press(forDuration:)` als Tippen an. Die Zeile ist ein `NavigationLink` (`LooseEnds/Views/TaskListView.swift:100-108`)
   und öffnet das Detail statt des Kontextmenüs. `openMenu` erkennt das nicht und drückt weitere Male ins
   Leere. Beleg: Bildschirmaufnahme im Artefakt `UITestResults` von CI-Lauf 36860656065.

## Dependencies

| Abhängigkeit | Art | Zweck |
|---|---|---|
| XCUITest | Upstream | Gesten, Wartebedingungen |
| Kennungen `viewRow_repeating`, `taskRow_*`, `menuDone`, `menuDelete`, `confirmDeleteButton`, `captureButton` | Upstream (App) | Navigation und Aktionen im Test |
| `ViewRules` „Repeating“ = `isOpen && repeatRule != nil` (`ViewRules.swift:32`) | Upstream (App) | Aufgabe bleibt unabhängig vom Modell in der Ansicht |
| `TaskActions.complete` rollt Wiederholungen vor, ohne Status oder Regel zu ändern | Upstream (App) | Aufgabe bleibt nach dem Abschließen in „Repeating“ |
| `testDoneFromMenuEmptiesNew` (Z. 185), `testCompletedTaskShowsUnderCompleted` (Z. 387) | Downstream | Weitere Aufrufer von `openMenu` |
| `scripts/sim.sh test-proof` (#145) | Downstream | Nachweis über die ganze Klasse |

## Scope

Dateien (2), geschätzt +30/-10 LoC.

Out of Scope:

- Kein Produktcode (`LooseEnds/`, `Shared/` bleiben unberührt).
- Keine Änderung am Wiederholungslauf in `.github/workflows/ci.yml` (Zeile 130). Ob er danach
  entfernt wird, ist ein eigenes Issue und wird nach Abschluss dieses Tickets angelegt.
- Keine Änderung an anderen UI-Tests, kein Abschalten des Modells unter `--ui-testing`.

## Implementation Details

1. Nach „Daily“ dreimal zurück (Editor → Detail → Liste → Sidebar) über
   `app.navigationBars.buttons.firstMatch`, wie in `testCompletedTaskShowsUnderCompleted`, dann
   `viewRow_repeating` antippen.
2. Die Zeile dort über `identifier BEGINSWITH "taskRow_"` suchen, nicht über den Titel.
3. `openMenu`: Bleibt das Menüelement nach einem Drücken aus und ist die Zeile verschwunden (Detail
   offen), tippt es auf die Zurück-Taste, wartet auf die Zeile und drückt mit der nächsten Dauer der
   bestehenden Folge 1,2/1,5/2,0 s erneut. Öffnet das Menü beim ersten Drücken, ändert sich nichts.

## Test Plan

Der geänderte Test ist der Nachweis.

- **RED:** Der aktuelle Test ist lokal mit Modell rot (Zeile 336), reproduziert am 2026-10-01 mit
  `./scripts/sim.sh test CaptureSmokeTests/testDeletingRecurringTaskAfterCompletionDoesNotCrash`
  (`** TEST FAILED **`, UI-Hierarchie: Ansicht „New“, `emptyViewLabel` „Nothing here“). Vor der
  Änderung wird das erneut festgehalten.
- **GREEN lokal:** `./scripts/sim.sh test-proof CaptureSmokeTests` dreimal hintereinander grün, mit
  aktivem Modell. Die Bildschirmaufnahmen werden geöffnet und beschrieben, nicht nur gezählt.
- **GREEN CI:** erster Versuch grün ohne Wiederholung (Ergebnisprotokoll des Laufs).
- Stufe 3 (Gerät): Kein Pfad der Geräteliste berührt.

## Acceptance Criteria

- **AC-1 (Zeile nach „Daily“ finden):** Given eine erfasste Aufgabe, der im Test „Daily“ gesetzt wurde,
  unabhängig davon, ob das Modell sie veredelt hat. When der Test zur Seitenleiste zurückgeht und
  `viewRow_repeating` öffnet. Then findet er die Zeile dort über die Kennung `taskRow_*`, nicht über
  den Titel.
- **AC-2 (Menü trotz Tippen):** Given das Drücken auf die Zeile kam als Tippen an und das Detail ist
  offen. When `openMenu` das erkennt. Then tippt es auf die Zurück-Taste, wartet auf die Zeile und
  drückt erneut, ohne die Versuchsfolge 1,2/1,5/2,0 s zu verlängern.
- **AC-3 (Aufrufer unverändert):** Given das Menü öffnet beim ersten Drücken. Then ändert der neue Pfad
  nichts. `testDoneFromMenuEmptiesNew` und `testCompletedTaskShowsUnderCompleted` bleiben im Quelltext
  unverändert und grün.
- **AC-4 (Ablauf des Tests):** Then führt der Test weiter: Abschließen über `menuDone`, Zeile bleibt
  gelistet, Löschen über `menuDelete` und `confirmDeleteButton`, Zeile verschwindet, `captureButton`
  antwortet (die App ist nicht abgestürzt).
- **AC-5 (Nachweis lokal):** `./scripts/sim.sh test-proof CaptureSmokeTests` ist dreimal hintereinander
  grün, lokal mit aktivem Modell. Der Beleg entsteht aus dem Lauf selbst.
- **AC-6 (Nachweis CI):** Der erste CI-Versuch ist grün, ohne dass `-retry-tests-on-failure` einen
  Test wiederholt hat.
- **AC-7 (Stand-Dokument):** `docs/project/04-stand.md` führt #20, #21 und #74 nicht mehr in der
  Prioritätsliste. Die übrigen Einträge und ihre Reihenfolge bleiben.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — reiner Testaufbau-Fix, keine bestehende ADR wird gekippt.

Alternative (nicht gewählt): Ein Launch-Argument schaltet
die Veredelung unter `--ui-testing` ab. Das machte alle UI-Tests deterministisch und löste Ursache 1 an
der Wurzel. Nicht gewählt, weil es Produktcode ändert und genau den Ablauf verdeckt, den Henning bekommt:
Eine Aufgabe mit KI-Feldern verlässt „New“. Der Test soll beide Pfade (mit und ohne Modell) tragen.
Kann als eigenes Ticket folgen.

## Risiken

- Das Modell kann den Titel umschreiben. Deshalb Suche über `taskRow_*`. In „Repeating“ liegt nur diese
  eine Aufgabe, solange der Test mit frischem Datenbestand startet (`--ui-testing`); das wird beim Umbau
  geprüft.
- Lokal (mit Modell) und CI (ohne) fahren verschiedene Pfade. Der Fix wird in beiden belegt (AC-5, AC-6).
- Der Wiederholungslauf der CI bleibt vorerst und kann andere Tests weiter verdecken. AC-6 verlangt
  deshalb den Blick ins Protokoll statt nur auf die Ampel.

## Definition of Done

- [ ] RED vor der Änderung erneut festgehalten (Zeile 336)
- [ ] AC-1 bis AC-7 erfüllt
- [ ] `./scripts/sim.sh test-proof CaptureSmokeTests` dreimal hintereinander grün, Screenshots angesehen und beschrieben
- [ ] Erster CI-Versuch grün ohne Wiederholung, im Protokoll geprüft
- [ ] Issue zur Entfernung von `-retry-tests-on-failure` angelegt
- [ ] Nach dem Zusammenführen: Hennings Hauptordner nachgezogen (`bash ~/.claude/scripts/loose-ends-sync-main.sh`)

## Changelog

- 2026-10-01: Spec aus der Analyse in `docs/context/bug-165-wiederholend-test.md` geschrieben.
