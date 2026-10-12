---
entity_id: fix-336-wiedererkennung-wackler
type: bugfix
created: 2026-10-12
updated: 2026-10-12
status: draft
workflow: fix-336-wiedererkennung-wackler
---

# Spec: #336 — Wackelnder Wiedererkennungs-UI-Test läuft beim ersten Versuch grün

## Approval

- [ ] Approved

## Purpose

`RecognitionWalkthroughTests` scheiterte in der CI einmal und bestand im zweiten Versuch. #336
verlangt, dass der Test beim ersten Versuch grün ist. Die Ursache liegt im Testcode, nicht im
Produkt: XCTest baut jeden Schnappschuss des Elementbaums auf dem Hauptthread der App, was auf dem
ausgelasteten CI-Rechner bis zu 29 s dauert. Die Hilfsfunktion `waitForLabel` hatte 10 s Frist und
bekam dadurch nur eine einzige Auswertung, die 9,2 s hing und einen leeren Baum lieferte. Diese
Spec hebt die Frist auf 60 s an, damit nach einem langsamen Schnappschuss noch eine zweite,
ebenso langsame Auswertung stattfinden kann. Es ändert sich kein Produktcode und nichts Sichtbares in der App.

## Source

- **File:** `LooseEndsUITests/RecognitionWalkthroughTests.swift`
- **Identifier:** `waitForLabel(_:of:timeout:)` (Zeile 128–134, Standardwert `timeout: TimeInterval = 10` in Zeile 130); sechs Aufrufer ohne eigene Frist (Zeile 167, 182, 207, 228, 234, 240)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `XCTNSPredicateExpectation` / `XCTWaiter` | framework | Wartemechanismus von `waitForLabel`; die Frist ist sein `timeout` |
| CI-Diagnose `watchdog.log`, `host-load.log` (`.github/workflows/ci.yml`) | tooling | Unverändert; protokolliert weiter jede Hauptthread-Blockade und belegt künftige Fälle |
| `docs/artifacts/fix-336-wiedererkennung-wackler/correlate.py` | tooling | Ordnet Watchdog-Blockaden den XCTest-Abfragen zu (Nachweis) |
| `./scripts/sim.sh test-proof <Klasse>` (#145) | tooling | Lokaler Nachweis mit maschinellem Simulator-Beleg |
| #172 (UI-Tests beim ersten Versuch grün, Wiederholung entfernt) | spec | Gemeinsames Ziel; Wiederholung bleibt entfernt |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEndsUITests/RecognitionWalkthroughTests.swift` | MODIFY | `waitForLabel`: Standardfrist 10 s → 60 s, begründender Kommentar mit Verweis auf #336 |

### Estimated Changes

- Files: 1
- LoC: +10/-3
- Nur Testcode. Keine neuen Abhängigkeiten, keine Berechtigungen, keine AppStorage-Schlüssel, keine Audiodateien.

## Definition of Done

- [ ] `waitForLabel` hat 60 s Standardfrist, Kommentar nennt Ursache und #336 (AC-1)
- [ ] Zusicherungen und Aufrufer unverändert (AC-2)
- [ ] Lokaler Lauf unter Zusatzlast vor und nach der Änderung, Blockade der Abfrage zugeordnet (AC-3)
- [ ] `./scripts/sim.sh test-proof RecognitionWalkthroughTests` ohne Last grün (AC-4)
- [ ] Drei CI-Läufe in Folge grün, am Protokoll geprüft (AC-5)
- [ ] Kein Produktcode geändert, `ci.yml` unverändert (AC-6)

## Implementation Details

### Root Cause

XCTest lässt jeden Schnappschuss des Elementbaums von der App auf deren Hauptthread bauen. Auf dem
ausgelasteten CI-Rechner dauert das bis zu 29 s. Im roten Lauf hing die erste und einzige Auswertung
von `waitForLabel` (10 s Frist) 9,2 s und lieferte einen leeren Baum; für eine zweite Auswertung
blieb keine Zeit.

Belege (Details in `docs/context/fix-336-wiedererkennung-wackler.md`, Abschnitt „Analysis"):

- 31 von 31 Watchdog-Blockaden ≥ 3 s des roten Laufs beginnen entweder beim Einrichten der Testsitzung
  oder 0,0–1,4 s nach einer Element-Abfrage von XCTest; ohne Test-Abfrage gibt es keine Blockade
  (Zuordnung per `correlate.py`).
- Fehlerstelle: Abfrage um :00,724, Blockade ab ≈ :00,8, Antwort um :09,877. Vorher meldete XCTest
  „Wait for … to idle" als erfüllt, die App war ruhig.
- Lokal im iOS-27-Simulator: Unter Zusatzlast (8× `yes`) blockierte der Hauptthread 35 s, 112 s und
  370 s. Die Fehlerklasse ist nachgestellt; der rote Testausgang selbst nicht deterministisch.
- Widerlegt: falsche Fläche, Zeile nicht oben, App-Arbeit beim Öffnen der Detailansicht.

Recherche (Quellen): Schnappschuss-Anfragen blockieren den Hauptthread der App, auf CI häufig bis zur
30-s-Grenze („Unable to perform work on main run loop, process main thread busy"):
https://origin-devforums.apple.com/forums/thread/741983,
https://developer.apple.com/forums/thread/708993,
https://developer.apple.com/forums/thread/133026

### Fix

In `waitForLabel(_:of:timeout:)` wird der Standardwert von `timeout` von `10` auf `60` gesetzt.
Begründung der Zahl: XCTest bricht einen einzelnen Schnappschuss nach 30 s ab („Timed out while
evaluating UI query"), länger kann eine Auswertung also nicht hängen. 60 s decken damit zwei
Auswertungen an dieser Grenze ab: Selbst wenn die erste 29 s hängt (der längste Hänger im roten
Lauf) und leer zurückkommt, bleibt Zeit für eine zweite, ebenso langsame. Eine Frist von 30 s
reichte dafür nicht: Nach einer ersten Auswertung von 29 s fände die zweite nicht mehr statt
(die Analyse hatte 30 s vorgeschlagen; korrigiert beim Schreiben der Spec). Über dem Standardwert steht ein
Kommentar: Schnappschüsse laufen auf dem Hauptthread der App und dauern auf dem CI-Rechner bis zu
29 s; die Frist muss zwei solche Auswertungen fassen (#336). Die Zusicherungen prüfen weiter genau
dieselbe Beschriftung (`label == …`); kein Aufrufer ändert sich.

### Risiko: längere Frist verdeckt einen echten App-Hänger

Entkräftet: (1) Der Watchdog schreibt jede Blockade weiter in `watchdog.log`, die Diagnose bleibt
vollständig. (2) Die Zusicherung bleibt gleich: Zeigt die App nie den erwarteten Wert, scheitert der
Test nach 60 s genauso, nur später. Im grünen Fall kostet die Frist nichts, weil die Wartehilfe beim
ersten Treffer zurückkehrt.

### Nachweis

RED ist nicht deterministisch erzwingbar, weil der Ausfall von der Auslastung des CI-Rechners
abhängt. Ersatz:

1. Lokaler Lauf im iOS-27-Simulator unter Zusatzlast (mehrere `yes`-Prozesse) vor der Änderung;
   Blockaden des Watchdogs werden mit `correlate.py` den Abfragen zugeordnet.
2. Derselbe Ablauf unter derselben Last nach der Änderung.
3. Grüner Lauf ohne Last: `./scripts/sim.sh test-proof RecognitionWalkthroughTests`, Screenshots
   geöffnet und beschrieben.
4. DoD von #336: drei CI-Läufe in Folge grün.

### Alternativen

- **Schnappschüsse billiger machen** (typisierte Abfragen `staticTexts`/`otherElements` statt `.any`,
  kleinerer Elementbaum der Detailansicht): Wirkung unbelegt, auch `Button (First Match)` blockierte
  3,1 s, und der Baum gehört zum Produkt. Vertagt; eine Messung wäre der erste Schritt, falls die
  Frist nicht reicht.
- **Gemeinsame Wartehilfe für alle UI-Tests** (lange Frist für jede `.any`-Abfrage): passt zum Ziel
  von #172, betrifft aber 6–8 Testdateien und sprengt die Limits (4–5 Dateien, ±250 LoC). Die anderen
  Tests blieben trotz Blockaden von 20–29 s grün, weil `waitForExistence` nach später Antwort erneut
  auswertet. Eigenes Ticket, falls weitere Wackler auftauchen.
- **Wiederholung in der CI:** brächte die in #172 entfernte Wiederholung zurück und kippte diese
  Entscheidung. Abgelehnt.
- **Größerer oder eigener CI-Rechner:** liegt außerhalb des Repos, kostet Geld und hängt am
  Vorschau-Image `xcode-27`. Nicht jetzt.

## Test Plan

Kein Produktcode, daher keine neuen Unit-Tests. Die Änderung ist der Testcode selbst; nachgewiesen
wird mit Läufen unter Last, ohne Last und in der CI.

### Automated Tests (TDD RED)

- [ ] Test 1 (RED-Ersatz): GIVEN `waitForLabel` mit 10 s Frist und Zusatzlast (mehrere `yes`-Prozesse) auf dem Simulator WHEN `./scripts/sim.sh test-proof RecognitionWalkthroughTests` läuft THEN werden Hauptthread-Blockaden im Watchdog-Protokoll sichtbar und per `correlate.py` einer Abfrage zugeordnet; scheitert der Test, wird die Ausgabe zitiert.
- [ ] Test 2 (GREEN unter Last): GIVEN `waitForLabel` mit 60 s Frist und dieselbe Last WHEN derselbe Lauf wiederholt wird THEN besteht `RecognitionWalkthroughTests` beim ersten Versuch, oder jede Blockade ist einer Abfrage zugeordnet und der Test besteht trotz Blockade.
- [ ] Test 3 (GREEN ohne Last): GIVEN die Änderung WHEN `./scripts/sim.sh test-proof RecognitionWalkthroughTests` ohne Zusatzlast läuft THEN ist der Test grün und der maschinelle Simulator-Beleg liegt vor.
- [ ] Test 4 (Zusicherung bleibt scharf): GIVEN die Änderung WHEN eine `waitForLabel`-Zusicherung einen falschen Wert erwartet (Wegwerf-Kopie) THEN scheitert der Test nach etwa 60 s.
- [ ] Test 5 (CI): GIVEN die Änderung auf `main` WHEN der Schritt „Run UI smoke tests" dreimal in Folge läuft THEN sind alle drei Läufe grün.

## Acceptance Criteria

- [ ] AC-1 `waitForLabel` in `LooseEndsUITests/RecognitionWalkthroughTests.swift` hat den Standardwert `timeout: TimeInterval = 60`; ein Kommentar nennt die Ursache (Schnappschüsse auf dem Hauptthread der App, bis zu 29 s, XCTest-Grenze 30 s je Schnappschuss) und #336.
- [ ] AC-2 Alle Zusicherungen und alle Aufrufer von `waitForLabel` sind unverändert; das Diff berührt in der Datei nur die Funktion und ihren Kommentar.
- [ ] AC-3 Ein lokaler Lauf im iOS-27-Simulator unter Zusatzlast liegt vor der Änderung und nach der Änderung vor; die Blockaden sind per `correlate.py` den Abfragen zugeordnet, die Ausgaben im Bericht zitiert.
- [ ] AC-4 `./scripts/sim.sh test-proof RecognitionWalkthroughTests` ist ohne Last grün (maschineller Beleg, Screenshots geöffnet und beschrieben).
- [ ] AC-5 Drei CI-Läufe in Folge sind grün, geprüft am Protokoll der Läufe (nicht am Endstatus allein); die Erfolgsprüfung steht im Ticket #336.
- [ ] AC-6 Kein Produktcode geändert und `.github/workflows/ci.yml` unverändert: Das Diff berührt genau die eine Datei aus dem Scope (ohne Dokumente unter `docs/`).
- [ ] AC-7 Geräteliste: Kein Pfad der Geräteliste berührt. Keine sichtbare UI-Änderung, daher keine Entwurfsvorschau.
- [ ] AC-8 Ausliefern: Nach dem Merge ist `bash ~/.claude/scripts/loose-ends-sync-main.sh` gelaufen.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — reine Anpassung einer Wartefrist im Testcode ohne Architekturwirkung; es wird keine bestehende Entscheidung gekippt oder neu getroffen.
- **Rationale:** Die Alternativen „CI-Wiederholung" (kippt die Entscheidung aus #172) und „gemeinsame Wartehilfe für alle UI-Tests" (eigenes Ticket) sind oben festgehalten. Wird eine davon nötig, ist das eine neue Entscheidung mit eigener Analyse.

## Changelog

- 2026-10-12: Initial spec created (Analyse in `docs/context/fix-336-wiedererkennung-wackler.md`).
