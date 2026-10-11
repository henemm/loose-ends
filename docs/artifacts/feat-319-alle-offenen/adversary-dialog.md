# Adversary Dialog — feat-319-alle-offenen
Spec: docs/specs/feat-319-alle-offenen.md
Datum: 2026-10-11 15:55

## Checkliste
- [x] **AC-1 Regel:** `ViewRules.tasks(for: .open, in:)` liefert jede Oberaufgabe mit `status != .done`: Neu (`unprocessed`, `unverified`), Aktiv, Wartende (blockiert) und Geparkte; erledigte Aufgaben und Unteraufgaben fehlen (Unit-Test).
- [x] **AC-2 Sortierung:** Die Liste steht nach Dringlichkeit, dann Wichtigkeit, dann `capturedAt` (dringend zuerst); geparkte Aufgaben sortieren nach denselben Werten mit (Unit-Test).
- [x] **AC-3 Fall und Texte:** `ViewKind.open` hat Titel „All open“ (DE „Alle offenen“) und Symbol `circle`; kein anderer Fall ändert sich; `everyViewHasAPlace` und die Unteraufgaben-Liste kennen `.open` (Unit-Tests grün).
- [x] **AC-4 Zeile:** Auf dem Startbildschirm steht in der letzten Section die Zeile `viewRow_open` direkt über `viewRow_done`, immer sichtbar (auch bei 0 Aufgaben, dann ohne Zahl wie alle Zeilen), mit Zähler = Anzahl der Liste (UI-Test prüft „2“ bei zwei offenen Aufgaben), Glyphe grau (UI-Test und Screenshot).
- [x] **AC-5 Öffnen:** Antippen der Zeile zeigt die Liste mit Navigationstitel „All open“, die offene und die geparkte, aber nicht die erledigte Aufgabe enthält (UI-Test).
- [x] **AC-6 Leersatz:** Ohne Aufgaben zeigt die Liste „Nothing left open.“ / „Nichts mehr offen.“ mit `emptyViewLabel` (UI-Test).
- [x] **AC-7 Geparkt erkennbar:** In „All open“ trägt nur die geparkte Zeile die graue Glyphe `moon.zzz` (`parkedMarker_<uuid>`, Accessibility-Label „Parked“); in „Geparkt“ erscheint sie nicht (UI-Test zählt dort null `parkedMarker_…`), in den übrigen Ansichten kommen geparkte Aufgaben nicht vor; Farbbudget eingehalten, kein Rot/Akzent (UI-Test, Screenshot).
- [x] **AC-8 Wisch nach rechts:** Auf jeder Zeile (auch der geparkten) bietet der Wisch nach rechts „Complete“ (`swipeDone_<uuid>`, grün wie überall) (UI-Test).
- [x] **AC-9 Wisch nach links:** Auf einer geparkten Zeile bietet der Wisch nach links „Activate“ (`swipeActivate_<uuid>`) und nicht „Next up“; auf allen anderen Zeilen „Next up“ bzw. „Remove from Next up“; „Activate“ nimmt die Mond-Glyphe, die Aufgabe bleibt in der Liste (UI-Test).
- [x] **AC-10 Langdruckmenü unverändert:** Geparkte Aufgabe: „Activate“ und „Delete“; alle anderen: das bisherige Menü (kein Codeeingriff in `menu(_:)`, durch den Diff belegt).
- [x] **AC-11 Alle Geräte, eine Oberfläche:** iPhone, iPad und Mac zeigen die Zeile aus derselben `SidebarView`; kein plattformspezifischer Code (Diff) und Simulator-Screenshot auf iPhone und iPad.
- [x] **AC-12 Keine Nebenwirkungen:** Kein Modellfeld, kein CloudKit-Schema (`mac-schema-init` entfällt), Widgets, Watch, Intents, Persistenz, `project.yml`, Entitlements und `Info.plist` unverändert (Diff); „Als nächstes“ und alle anderen Ansichten liefern unverändert dieselben Listen (bestehende Unit-Tests grün).
- [x] **AC-13 Doku:** `docs/project/02-datenmodell-und-ansichten.md` enthält die Zeile „Alle offenen“ mit Regel und Sortierung und nennt die Ausnahme in der Einleitung.
- [x] **AC-14 Regression und Abnahme:** Unit, Build und UI-Smoke grün; Stufe 2 (Simulator-Durchlauf mit Screenshots hell und dunkel, angesehen); Abschlussbericht mit dem Satz „Kein Pfad der Geräteliste berührt.“

## Dialog

### Runde 1
**Adversary:** Eigener Unit-Lauf (`./scripts/sim.sh unit`, Session feat319adv): 533 ✔, 0 ✘, Test Succeeded; Ausgabe: docs/artifacts/feat-319-alle-offenen/adversary-unit-output.txt. Ueberschriebene Messberichte in docs/reference zurueckgesetzt. 1 von 5 Messstrecken uebersprungen (Messung, kein Test). Regel geprueft: `case .open` filtert `status != .done` auf `topLevel` (parent == nil), sortiert mit `byUrgencyThenImportance`; nutzt nicht `isOpen`. Zaehler (SidebarView) und Liste (`TaskListView.shown`) lesen dieselbe Funktion, keine Abweichung. Wartend/blockiert ist kein Status, daher eingeschlossen. Unteraufgabe einer geparkten Aufgabe: nur die Oberaufgabe erscheint. Watch/Widgets/Share/Intents referenzieren `ViewKind` nicht (Suche leer); Shared/ nur um Enum-Fall erweitert, kein SwiftUI dort. TaskInteractions/TaskRow nutzen nur plattformneutrale APIs (`swipeActions`, `Image(systemName:)`).
**Implementierer:** (nicht Teil des Auftrags; Belege aus Diff und Laeufen)

### Runde 2
**Adversary:** Angriff auf die Testaenderung `taskRows` (descendants(.any) -> buttons): zulaessig. Die Zeile ist ein NavigationLink-Button; Kennung steht auf Zelle und Text, `.any` zaehlte doppelt. Die Zusicherungen (count == 2, parked == 1, in Parked 0) bleiben streng; die positive Zaehlung 2/1 beweist, dass Zeilen gefunden werden, daher kein vakuoeses Gruen im Parked-Fall. Schwaeche: der Mond wird ueber `label CONTAINS 'Parked'` statt ueber `parkedMarker_<uuid>` gezaehlt. Funktional gleichwertig (Label stammt aus dem accessibilityLabel der Glyphe). UI-Lauf (vorliegend): 8 Tests, 0 Failures; Screenshots geoeffnet: Startbildschirm zeigt graue Kreis-Glyphe, "All open 2" direkt ueber "Completed 1", Liste "All open" mit zwei Zeilen, nur "Fahrrad verkaufen" mit grauem Mond. Langdruckmenue: `menu(_:)` nicht im Diff (nur Kopfkommentar und trailingActions). Entitlements-Aenderung im Arbeitsbaum (zwei Zeilen geloescht) gehoert laut Spec nicht zum Ticket; am Ticket-Diff ohne diese Datei keine Aenderung an Persistenz, project.yml, Info.plist, Modell. Doku: Zeile, kind-Aufzaehlung und Einleitung vorhanden. Offen (nicht bewiesen): iPad-Screenshot, dunkle Screenshots, voller UI-Smoke, eigener macOS/watchOS-Build (nur Quellpruefung), Abschlussbericht-Satz.

### Runde 3
**Adversary:** Nachgelieferte Belege geprueft. F001 behoben: `parkedMarkers(in:)` (app.images, BEGINSWITH 'parkedMarker_') zaehlt in All open genau 1 und vergleicht die Kennung mit der geparkten Zeile, in Parked 0, im Wischtest vor Activate 1 und danach 0 (waitForNonExistence); die Zusicherungen sind strenger als zuvor, nichts aufgeweicht. UI-Lauf nach der Teststaenderung (ui-test-green-output.txt): 8 Tests, 0 failures, Test Succeeded. Produktcode laut Diff gegenueber Runde 1 unveraendert (Shared/Models, LooseEnds/Views). Stufe-2-Bilder geoeffnet: ipad-light.png (Seitenleiste "All open 2" ueber "Completed 1", Liste rechts mit grauem Mond nur an "Fahrrad verkaufen"; die ausgewaehlte Zeile ist im hellen Modus fast unlesbar, bestand laut Koordinator auch bei "Parked" vorher, #334, ausserhalb des Tickets), ipad-dark.png (gut lesbar, Mond grau), iphone-dark-start.png (Kreis-Glyphe grau, "All open 2" ueber "Completed 1"), iphone-dark-list.png (zwei Zeilen, grauer Mond, kein Akzent, kein Rot). AC-11 damit belegt (iPhone und iPad, eine SidebarView). macOS-Build laut Koordinator Build Succeeded (nicht selbst wiederholt). AC-14 bleibt offen: voller UI-Smoke-Lauf (CI, 34-39 Min.) und der Abschlussbericht-Satz liegen nicht vor; beides gehoert zu /60-validate bzw. Abschluss und kann in dieser Phase nicht als belegt gelten.
**Implementierer:** Belege nachgeliefert (Koordinator).

### Runde 4
**Adversary:** Voller lokaler UI-Lauf (ui-smoke-full/summary.txt) geprueft: 14 von 15 Klassen rc=0, StartScreenInteractionTests 8 Tests 0 failures (Test Succeeded). Rot: CalendarTargetTests/testSwitchOnShowsTargetCalendar (rc=65, Meldung "The detail should name the calendar the event goes to", im Lauf und Wiederholung). Unabhaengigkeit vom Diff geprueft: der Test nutzt nur captureButton, captureTextField, viewRow_new und das Aufgabendetail; er beruehrt weder viewRow_open, All open, TaskRow-Mond noch Wischaktionen. `diff --name-only` des Tickets enthaelt keine Kalender-/Detail-Dateien (nur Enums, ViewRules, SidebarView, TaskListView, TaskRow, TaskInteractions, Katalog, UI-Test, Doku, entitlements). Die Behauptung, derselbe Test sei auf dem Ausgangsstand 9e889ef lokal rot und in CI gruen (#305), habe ich NICHT selbst nachgestellt; sie stuetzt sich auf den Beleg im Ticket-Kommentar. Geraeteliste: Ticket-Diff ohne LooseEnds.entitlements beruehrt keinen Pfad der CLAUDE.md-Liste (kein Persistence, Enrichment, Watch, Widgets, Share, Intents, Speech, Notifications, project.yml, Info.plist); die entitlements-Aenderung (zwei Zeilen ubiquity-kvstore-identifier geloescht) ist laut Koordinator aus #311 und steht nicht im Ticket-Commit. Der Satz "Kein Pfad der Geraeteliste beruehrt." ist damit begruendet. 04-stand.md im Diff ergaenzt. AC-14 bewertet: Unit 533 gruen, Build (iOS, macOS) gruen, UI-Smoke bis auf den bekannten Kalendertest gruen, Stufe 2 hell/dunkel iPhone und iPad belegt, Satz begruendet. Der rote Test ist kein Befund gegen #319, bleibt aber ein roter Test im Lauf.
**Implementierer:** Belege nachgeliefert (Koordinator).

### Findings
Finding:
  ID: F001
  Severity: LOW
  Category: anti_pattern
  Code reference: LooseEndsUITests/StartScreenInteractionTests.swift:244
  Description: [BEHOBEN in Runde 3, Pruefung ueber parkedMarker_ per app.images] Der Mond wurde in den UI-Tests ueber `label CONTAINS 'Parked'` gezaehlt, nicht ueber `parkedMarker_<uuid>`.
  Spec requirement: AC-7 — zaehlt `parkedMarker_...` (null in Geparkt, eins in All open)
  Conflict: Indirekte Pruefung; die Kennung der Glyphe selbst wird nie angefragt.
  Remediation: Zusaetzlich `element("parkedMarker_<id>")` pruefen.

Finding:
  ID: F002
  Severity: LOW
  Category: spec_violation
  Code reference: LooseEnds/Views/SidebarView.swift:117
  Description: [ERLEDIGT in Runde 4] Belege fuer AC-11 und AC-14 nachgeliefert.
  Spec requirement: AC-11, AC-14 — Screenshots iPad, hell und dunkel
  Conflict: Beleg fehlt; kein Codefehler.
  Remediation: In /60-validate Stufe 2 nachholen.

Finding:
  ID: F003
  Severity: MEDIUM
  Category: regression
  Code reference: LooseEndsUITests/StartScreenInteractionTests.swift:244
  Description: CalendarTargetTests/testSwitchOnShowsTargetCalendar ist im vollen lokalen UI-Lauf rot (ui-smoke-full/CalendarTargetTests.txt:74). Der Test haengt nach Quelltext nicht von den geaenderten Dateien ab; als vorbestehend (#305) belegt nur durch Kommentar, nicht von mir nachgestellt.
  Spec requirement: AC-14 — UI-Smoke gruen
  Conflict: Strikt gelesen ist der Smoke nicht vollstaendig gruen.
  Remediation: #305 beheben oder per override-ambiguous freigeben.

### Confirmations
Confirmation:
  AC: AC-1
  Code reference: Shared/Models/ViewRules.swift:96
  Evidence: `status != .done` auf topLevel; Unit-Tests openViewContainsEveryUnfinishedTask und openViewExcludesDoneAndSubtasks gruen (533 ✔).
  Status: CONFIRMED
Confirmation:
  AC: AC-2
  Code reference: Shared/Models/ViewRules.swift:99
  Evidence: sorted(by: byUrgencyThenImportance); Test openViewSortsUrgentFirst gruen.
  Status: CONFIRMED
Confirmation:
  AC: AC-3
  Code reference: Shared/Models/Enums.swift:78
  Evidence: Titel "All open", Symbol "circle" (Zeile 96), DE-Texte im Katalog; Test openViewTitleAndSymbol gruen.
  Status: CONFIRMED
Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Views/SidebarView.swift:118
  Evidence: countRow viewRow_open vor viewRow_done, ohne if; UI-Test prueft minY und Zaehler "2"; Screenshot angesehen.
  Status: CONFIRMED
Confirmation:
  AC: AC-5
  Code reference: LooseEnds/Views/TaskListView.swift:43
  Evidence: shown liest ViewRules.tasks(for: .open); Titel via kind.titleKey; UI-Test: Navigationsleiste "All open", 2 Zeilen; Screenshot.
  Status: CONFIRMED
Confirmation:
  AC: AC-6
  Code reference: LooseEnds/Views/TaskListView.swift:116
  Evidence: emptySentence .open; UI-Test testOpenViewEmptySentence gruen.
  Status: CONFIRMED
Confirmation:
  AC: AC-7
  Code reference: LooseEnds/Views/TaskRow.swift:46
  Evidence: nur marksParked && status == .parked, .secondary, Label "Parked", Kennung parkedMarker_; marksParked nur bei kind == .open (TaskListView.swift:272,279); UI-Test Parked 0.
  Status: CONFIRMED
Confirmation:
  AC: AC-8
  Code reference: LooseEnds/Views/TaskInteractions.swift:73
  Evidence: leadingActions unveraendert, default = Complete mit swipeDone_; UI-Test auf geparkter Zeile.
  Status: CONFIRMED
Confirmation:
  AC: AC-9
  Code reference: LooseEnds/Views/TaskInteractions.swift:86
  Evidence: `.open? where status == .parked` -> Activate (swipeActivate_), sonst nextUpAction; TaskActions.activate setzt .active, Zeile bleibt; UI-Test gruen.
  Status: CONFIRMED
Confirmation:
  AC: AC-10
  Code reference: LooseEnds/Views/TaskInteractions.swift:7
  Evidence: Diff beruehrt menu(_:) nicht, nur Kopfkommentar und trailingActions.
  Status: CONFIRMED
Confirmation:
  AC: AC-12
  Code reference: Shared/Models/Enums.swift:64
  Evidence: Nur Enum-Fall und Regel; Ticket-Diff ohne Modell, Persistenz, Watch, Widgets, Intents, project.yml, Info.plist; bestehende Tests gruen.
  Status: CONFIRMED
Confirmation:
  AC: AC-13
  Code reference: docs/project/02-datenmodell-und-ansichten.md:136
  Evidence: Tabellenzeile, kind-Aufzaehlung und Einleitungsausnahme im Diff vorhanden.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: AMBIGUOUS
═══════════════════════════════════════
Ambiguous findings (require human review):
  F003: Kalendertest rot (vorbestehend laut #305, nicht von mir nachgestellt) — kein Befund gegen #319 nach Quelltext, aber ein roter Test im Lauf; Regel verbietet VERIFIED bei rotem Test.

Proven points: 14/14 (AC-14 mit dem Vorbehalt F003)
Tests: Unit 533 passed, 0 failed; UI 14 von 15 Klassen gruen, 1 Test rot (#305)
Recommendation: Nutzer prueft F003 und gibt per override-ambiguous frei (oder #305 zuerst).

## Geprüfte Dateien

- sha256:a28a9e8dc4da67cada427e5b197f04b329c5e3742abbee1031021d896b156278  LooseEnds/Views/SidebarView.swift
- sha256:780971745a31feb5881d9ad525e1a9e9210a0baeab04659f10674c0007673366  LooseEnds/Views/TaskInteractions.swift
- sha256:5ebe5b038bdf1904c5fbe600ef2b9c9413c86d8fbabf49427e00b043ccb0ca26  LooseEnds/Views/TaskListView.swift
- sha256:fba0cd6e47aff8c0cfa0743a7c42057b1264fa862de44510e02b04e433afe143  LooseEnds/Views/TaskRow.swift
- sha256:5543e1ee350eadc2a68e800ecd17cd553938030302aa51278387a2840ec7d9a1  LooseEndsUITests/StartScreenInteractionTests.swift
- sha256:cdf149cb0a26937279b40d3175de6f54ebc8b7f7838ee716b34a31a90ad3497a  Shared/Models/Enums.swift
- sha256:6ad011d02e7562505e71cfc93844a7c6548205069789758a7b8c2ecd0fc05e06  Shared/Models/ViewRules.swift
- sha256:d75ac0057e633e193b182990335a1c142ab430ae47a8ce7fc2eef332216e34c6  docs/project/02-datenmodell-und-ansichten.md

## Prüfbasis

- base: 9e889efa12a0955bf7cda533b2a79c38855df753
- blob:bc9d0dd36dd8765a5ee3775ecf7f8aa11bb31ad6  LooseEnds/Views/SidebarView.swift
- blob:e7fe792ea488a081fa0be5919385b25bd208933d  LooseEnds/Views/TaskInteractions.swift
- blob:1df7631d2b6683cd6c897d5e470b42024b8c2999  LooseEnds/Views/TaskListView.swift
- blob:ee4a6a4a49c7c89cd411507b917b817500687e6e  LooseEnds/Views/TaskRow.swift
- blob:0b1fd87368de2fd72189ad17437180f0f12cb72b  LooseEndsUITests/StartScreenInteractionTests.swift
- blob:0a1ce78621ba0b5240c6183ed70dd419e24a67a6  Shared/Models/Enums.swift
- blob:d3ae5b07caaa1c7e495afa7c4e8999c02d0424db  Shared/Models/ViewRules.swift
- blob:b0f1fe5de91fdcb0e3e441daffcbac1ce78a71c2  docs/project/02-datenmodell-und-ansichten.md

## Geprüfte Dateien

- sha256:a28a9e8dc4da67cada427e5b197f04b329c5e3742abbee1031021d896b156278  LooseEnds/Views/SidebarView.swift
- sha256:780971745a31feb5881d9ad525e1a9e9210a0baeab04659f10674c0007673366  LooseEnds/Views/TaskInteractions.swift
- sha256:5ebe5b038bdf1904c5fbe600ef2b9c9413c86d8fbabf49427e00b043ccb0ca26  LooseEnds/Views/TaskListView.swift
- sha256:fba0cd6e47aff8c0cfa0743a7c42057b1264fa862de44510e02b04e433afe143  LooseEnds/Views/TaskRow.swift
- sha256:5543e1ee350eadc2a68e800ecd17cd553938030302aa51278387a2840ec7d9a1  LooseEndsUITests/StartScreenInteractionTests.swift
- sha256:cdf149cb0a26937279b40d3175de6f54ebc8b7f7838ee716b34a31a90ad3497a  Shared/Models/Enums.swift
- sha256:6ad011d02e7562505e71cfc93844a7c6548205069789758a7b8c2ecd0fc05e06  Shared/Models/ViewRules.swift
- sha256:d75ac0057e633e193b182990335a1c142ab430ae47a8ce7fc2eef332216e34c6  docs/project/02-datenmodell-und-ansichten.md

## Prüfbasis

- base: 9e889efa12a0955bf7cda533b2a79c38855df753
- blob:bc9d0dd36dd8765a5ee3775ecf7f8aa11bb31ad6  LooseEnds/Views/SidebarView.swift
- blob:e7fe792ea488a081fa0be5919385b25bd208933d  LooseEnds/Views/TaskInteractions.swift
- blob:1df7631d2b6683cd6c897d5e470b42024b8c2999  LooseEnds/Views/TaskListView.swift
- blob:ee4a6a4a49c7c89cd411507b917b817500687e6e  LooseEnds/Views/TaskRow.swift
- blob:0b1fd87368de2fd72189ad17437180f0f12cb72b  LooseEndsUITests/StartScreenInteractionTests.swift
- blob:0a1ce78621ba0b5240c6183ed70dd419e24a67a6  Shared/Models/Enums.swift
- blob:d3ae5b07caaa1c7e495afa7c4e8999c02d0424db  Shared/Models/ViewRules.swift
- blob:b0f1fe5de91fdcb0e3e441daffcbac1ce78a71c2  docs/project/02-datenmodell-und-ansichten.md

## Geprüfte Dateien

- sha256:a28a9e8dc4da67cada427e5b197f04b329c5e3742abbee1031021d896b156278  LooseEnds/Views/SidebarView.swift
- sha256:780971745a31feb5881d9ad525e1a9e9210a0baeab04659f10674c0007673366  LooseEnds/Views/TaskInteractions.swift
- sha256:5ebe5b038bdf1904c5fbe600ef2b9c9413c86d8fbabf49427e00b043ccb0ca26  LooseEnds/Views/TaskListView.swift
- sha256:fba0cd6e47aff8c0cfa0743a7c42057b1264fa862de44510e02b04e433afe143  LooseEnds/Views/TaskRow.swift
- sha256:776f94e0149711a0123b49a171c3e7363587a65c5848eda6e3289f68eb97c1b0  LooseEndsUITests/StartScreenInteractionTests.swift
- sha256:cdf149cb0a26937279b40d3175de6f54ebc8b7f7838ee716b34a31a90ad3497a  Shared/Models/Enums.swift
- sha256:6ad011d02e7562505e71cfc93844a7c6548205069789758a7b8c2ecd0fc05e06  Shared/Models/ViewRules.swift
- sha256:d75ac0057e633e193b182990335a1c142ab430ae47a8ce7fc2eef332216e34c6  docs/project/02-datenmodell-und-ansichten.md

## Prüfbasis

- base: 9e889efa12a0955bf7cda533b2a79c38855df753
- blob:bc9d0dd36dd8765a5ee3775ecf7f8aa11bb31ad6  LooseEnds/Views/SidebarView.swift
- blob:e7fe792ea488a081fa0be5919385b25bd208933d  LooseEnds/Views/TaskInteractions.swift
- blob:1df7631d2b6683cd6c897d5e470b42024b8c2999  LooseEnds/Views/TaskListView.swift
- blob:ee4a6a4a49c7c89cd411507b917b817500687e6e  LooseEnds/Views/TaskRow.swift
- blob:3952b5dcd9f75ea77f05b3ca50ede7f8c1740e6b  LooseEndsUITests/StartScreenInteractionTests.swift
- blob:0a1ce78621ba0b5240c6183ed70dd419e24a67a6  Shared/Models/Enums.swift
- blob:d3ae5b07caaa1c7e495afa7c4e8999c02d0424db  Shared/Models/ViewRules.swift
- blob:b0f1fe5de91fdcb0e3e441daffcbac1ce78a71c2  docs/project/02-datenmodell-und-ansichten.md

## Geprüfte Dateien

- sha256:a28a9e8dc4da67cada427e5b197f04b329c5e3742abbee1031021d896b156278  LooseEnds/Views/SidebarView.swift
- sha256:780971745a31feb5881d9ad525e1a9e9210a0baeab04659f10674c0007673366  LooseEnds/Views/TaskInteractions.swift
- sha256:5ebe5b038bdf1904c5fbe600ef2b9c9413c86d8fbabf49427e00b043ccb0ca26  LooseEnds/Views/TaskListView.swift
- sha256:fba0cd6e47aff8c0cfa0743a7c42057b1264fa862de44510e02b04e433afe143  LooseEnds/Views/TaskRow.swift
- sha256:776f94e0149711a0123b49a171c3e7363587a65c5848eda6e3289f68eb97c1b0  LooseEndsUITests/StartScreenInteractionTests.swift
- sha256:cdf149cb0a26937279b40d3175de6f54ebc8b7f7838ee716b34a31a90ad3497a  Shared/Models/Enums.swift
- sha256:6ad011d02e7562505e71cfc93844a7c6548205069789758a7b8c2ecd0fc05e06  Shared/Models/ViewRules.swift
- sha256:d75ac0057e633e193b182990335a1c142ab430ae47a8ce7fc2eef332216e34c6  docs/project/02-datenmodell-und-ansichten.md

## Prüfbasis

- base: 9e889efa12a0955bf7cda533b2a79c38855df753
- blob:bc9d0dd36dd8765a5ee3775ecf7f8aa11bb31ad6  LooseEnds/Views/SidebarView.swift
- blob:e7fe792ea488a081fa0be5919385b25bd208933d  LooseEnds/Views/TaskInteractions.swift
- blob:1df7631d2b6683cd6c897d5e470b42024b8c2999  LooseEnds/Views/TaskListView.swift
- blob:ee4a6a4a49c7c89cd411507b917b817500687e6e  LooseEnds/Views/TaskRow.swift
- blob:3952b5dcd9f75ea77f05b3ca50ede7f8c1740e6b  LooseEndsUITests/StartScreenInteractionTests.swift
- blob:0a1ce78621ba0b5240c6183ed70dd419e24a67a6  Shared/Models/Enums.swift
- blob:d3ae5b07caaa1c7e495afa7c4e8999c02d0424db  Shared/Models/ViewRules.swift
- blob:b0f1fe5de91fdcb0e3e441daffcbac1ce78a71c2  docs/project/02-datenmodell-und-ansichten.md
