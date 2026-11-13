# Adversary Dialog — fix-883-widget-schnitt2
Spec: docs/specs/fix-883-widget-nachziehen-schnitt2.md
Datum: 2026-11-13

## Checkliste
- [x] **AC-3:** Eine im Unit-Test gesendete „App wird aktiv“-Meldung löst genau ein Neuladen aus; zehn Meldungen innerhalb einer Sekunde ergeben genau eines (Unit-Test, Neuladen eingespeist).
- [x] **AC-4:** Die Beobachter von Schnitt 1 (Speichern, beendeter Import) laden weiter neu: alle `WidgetReloadTests` aus Schnitt 1 bleiben grün.
- [x] **AC-6:** `./scripts/sim.sh unit` und `build` grün, `generate` hinterlässt keinen Diff.
- [x] **AC-7:** Simulator-Durchlauf (App starten, Aufgabe erfassen, in den Hintergrund und zurück) ohne Absturz; `WidgetReload` schreibt bei jedem Neuladen die feste Protokollzeile `Widget reload requested` (Kategorie „Widget“, Subsystem `com.henning.looseends`), im Simulator-Log nach dem Zurückkehren in den Vordergrund mindestens einmal zu finden. (Einschränkung: im Durchlauf wurde keine Aufgabe erfasst, siehe Runde 2.)

## Bestätigungen und Befunde

Confirmation: AC-3
Code reference: LooseEnds/App/WidgetReload.swift:84
Evidence: Der Beobachter auf `Self.becameActive` ruft `reloadSoon()` auf (Zeilen 84–88). `reloadSoon()` bricht `pending` ab und startet einen neuen Task mit 1 s Debounce (Zeilen 104–113). Zehn Meldungen ergeben genau ein Neuladen. Tests `testBecomingActiveReloadsOnce` und `testBurstOfActiveMessagesReloadsOnce` in LooseEndsTests/WidgetReloadTests.swift:80-98; beide waren vor der Implementierung rot (docs/artifacts/fix-883-widget-schnitt2/test-red-output.txt).
Status: CONFIRMED

Confirmation: AC-4
Code reference: LooseEnds/App/WidgetReload.swift:61
Evidence: Die Beobachter für `ModelContext.didSave` (Zeile 61) und `eventChangedNotification` (Zeile 68) sind im Diff unverändert. Alle 8 Tests der Suite „WidgetReload (#883)“ sind grün (test-green-output.txt, eigener Prüferlauf rc=0).
Status: CONFIRMED

Confirmation: AC-6
Code reference: LooseEnds/App/WidgetReload.swift:8
Evidence: ac6-unit.txt: „Unit-Tests bestanden“, 24 XCTest ohne Fehler, Swift-Testing-Suiten ohne Fehler. ac6-build.txt: „Build Succeeded“. ac6-generate.txt und Live-`git status`: einzige geänderte versionierte Datei ist WidgetReload.swift, also kein `generate`-Diff. Übersprungen und einzeln benannt: RawSentenceReportTests, SelfConsistencyReportTests, TextFormModelReportTests (fehlende Korpusdateien), zwei Latenzschutz-Messungen (#274, de_DE im Simulator nicht verfügbar); alle ohne Bezug zum Schnitt.
Status: CONFIRMED

Confirmation: AC-7
Code reference: LooseEnds/App/WidgetReload.swift:52
Evidence: Der Produkt-Closure schreibt „Widget reload requested“ direkt vor `reloadTimelines`. Simulator-Durchlauf ohne `--ui-testing`, Prozess 30482 (gleiche PID vor und nach dem Wechsel, kein Absturz): 09:51:41 „listens for saves, imports and becoming active“, 09:52:02 „Widget reload requested“ eine Sekunde nach der Rückkehr (ac7-log.txt, ac7-log-stream.txt, Screenshots ac7-1 bis ac7-3).
Status: CONFIRMED

Findings: keine blockierenden.

Hinweis N1 (LOW, kein Blocker): Der macOS-Zweig (`NSApplication.didBecomeActiveNotification`) wurde nicht lokal gebaut; ihn deckt der CI-Job „Unit Tests (macOS destination)“ ab, und `ClaudeSyncTrigger.swift:27` nutzt dieselbe Notification.
Code reference: LooseEnds/App/WidgetReload.swift:35

## Dialog

### Runde 1
**Adversary:**
1. Trägt der Test? Würde er auch gegen eine falsche Implementierung rot?
2. Doppelter `start()`-Aufruf: doppelte Beobachter?
3. Lebensdauer: Wird ein Beobachter freigegeben, oder hält die Closure die Instanz fest?
4. Isolation: Ist `MainActor.assumeIsolated` mit `queue: .main` korrekt?
5. macOS: Kompiliert der AppKit-Zweig?
6. Burst: Was bewirkt die Entprellung?

**Implementierer:**
1. Mutation „Beobachter entfernt“: test-red-output.txt zeigt beide neuen Tests rot („Expectation failed: counter.count == 1“). Ohne Entprellung wäre der Burst-Test mit 10 rot; auf eine falsche Notification bekäme der Einzeltest 0 und wäre rot.
2. Der Guard `saveObserver == nil` (WidgetReload.swift:60) sitzt vor allen drei Beobachtern, die gemeinsam gesetzt werden; ein zweiter Aufruf kehrt vorher zurück, ein Teilzustand ist nicht erreichbar.
3. Alle drei Closures erfassen `[weak self]`; Besitzer ist `let widgetReload` in LooseEndsApp.swift:14, lebt so lange wie der Prozess.
4. `queue: .main` plus `assumeIsolated` ist dasselbe Muster wie bei den bestehenden Beobachtern; die Tests laufen ohne Trap.
5. `#if canImport(UIKit)` auf iOS, sonst `#elseif canImport(AppKit)`; Mac-Build über CI (siehe N1).
6. Debounce 60 ms im Test, 1 s im Produkt; ein Neuladen nach der letzten Meldung.

### Runde 2
**Adversary:**
a) AC-7 verlangt „Aufgabe erfassen“, im Durchlauf wurde keine erfasst. Trägt der Beleg?
b) Die Zeile um 09:51:44 nach dem Start ist nicht eindeutig zuzuordnen. Ist die Zeile von 09:52:02 die Rückkehr?
c) Zählen echte `UIApplication`-Meldungen des Testhosts mit, sodass der Zähler flackert?
d) Läuft beim ersten Start ein Neuladen, und ist das schädlich?

**Implementierer:**
a) Der Auslöser ist `didBecomeActive`, nicht ein Speichern; das Erfassen ist nur Vorspiel. Der Durchlauf belegt, dass die Kette im echten Prozess schließt, nicht dass ein erfasster Inhalt im Widget landet; das bleibt beim Gerätepunkt (Stufe 3, TestFlight) der Definition of Done.
b) Zeitleiste: Start 09:51:41, Screenshot Hintergrund 09:51:57, Screenshot zurück 09:52:04; die Zeile 09:52:02 liegt dazwischen, eine Sekunde Debounce nach der Rückkehr. Gleiche PID. Die Zeile nach dem Start ist das erste Aktivwerden, erwartet.
c) Im Test-Host ist der Produkt-Closure unterdrückt; die Test-Instanzen zählen mit Fenster 400 ms gegen 60 ms Debounce, Rot- und Grün-Lauf stabil bei genau 1.
d) Erwartet und unkritisch: ein zusätzlicher `reloadTimelines`-Aufruf beim Start.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Der Schnitt schreibt kein Modellfeld, nur einen Beobachter; keine Verdachtszeilen.

## Verdict
**VERIFIED**

Alle vier Punkte sind mit Fundstelle belegt, Tests wären ohne den Beobachter rot, Build und Unit-Tests grün, `generate` ohne Diff. Offene Grenzen, kein Blocker: keine Aufgabe im Simulator-Durchlauf erfasst; Mac-Zweig nur über die CI.

## Geprüfte Dateien

- sha256:03d93183261edf2a281850473ead3e987cc3cafd6320d6b0ef4f78849ac018f8  LooseEnds/App/WidgetReload.swift

## Prüfbasis

- base: 646c64252ff77f40fd8127875b08568351d55360
- blob:dcc1b424a4e04d217d91fbed73d6aad8bb3e7416  LooseEnds/App/WidgetReload.swift
