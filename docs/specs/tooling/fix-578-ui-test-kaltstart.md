---
entity_id: fix-578-ui-test-kaltstart
type: bugfix
created: 2026-10-21
updated: 2026-10-21
status: draft
workflow: fix-578-ui-test-kaltstart
---

# Spec: #578 — UI-Test nach kaltem Simulatorstart beim ersten Versuch grün

## Approval

- [ ] Approved

## Purpose

`CalendarTargetTests.testDefaultCalendarIsStampedOnSwitchOn` fällt in der CI als erster UI-Test nach einem frisch gestarteten
Simulator, bei sonst unverändertem Stand. Ziel: Der Test (und jeder andere UI-Test im Job `UI Smoke`) ist beim ersten Versuch
grün, auch als erster Test; die Ursache ist behoben, nicht nur ein Timeout erhöht.

**Hat es bisher funktioniert?** Ja, die Suite lief seit #203 grün; zwei Ausfälle am 2026-10-20 (PR #577, Lauf 39378870415,
Versuch 1; main 696322c, Lauf 39457247533). Nur der zweite ist ausgewertet (Log des ersten ist überschrieben). Was sich
geändert hat, ist die Last auf dem Läufer, nicht der Stand: Übersetzen und Simulatorstart überlappen (`host-load.log`).

**Ursachen (am CI-Lauf 39457247533 belegt, Bildfolge in `docs/artifacts/fix-578-ui-test-kaltstart/`):**

1. Der Tastatur-Hinweis „Speed up your typing …“ liegt beim ersten Öffnen des Erfassen-Blatts rund 50 s über der Tastatur.
   `scripts/sim.sh boot` schaltet ihn seit #341 ab, der Job `ui-smoke` in `ci.yml` nicht.
2. Der Test wartet nur 3 s auf den Kalender-Dialog (`allowCalendarAccessIfAsked`, `CalendarTargetTests.swift`); der Dialog kam
   bei t≈122 s, die Frist lief bei t≈121 s ab, danach fand der Test `calendarTargetRow` nie.
3. Der Dialog blieb stehen, weil `addUIInterruptionMonitor` ihn nicht fängt („Failed to construct element query matching
   interruption … element application: (null)“) und zog 25 Folgetests in 5 Suiten mit. Die Annahme im Test-Kommentar („ein später
   Dialog wird vom Monitor bei der nächsten Geste gefangen“) gilt unter iOS 27 nicht verlässlich; [Apple bestätigt, dass der Handler
   SpringBoard-Alerts seit iOS 17 nicht zuverlässig sieht](https://developer.apple.com/forums/thread/737880).
4. Der Läufer ist unter Last (Hauptthread der App bis 22,5 s blockiert, `watchdog.log`). Nicht behebbar, nur die Abhängigkeit
   von Fristen lässt sich mindern.

**Reproduktion (Regel „Reproduktion zuerst“):** Der Fehler ist am roten CI-Lauf 39457247533 mit Aufzeichnung, Log und Bildfolge
belegt (`docs/artifacts/fix-578-ui-test-kaltstart/`), auf genau dem Weg, auf dem er auftritt (der Job `UI Smoke`, nicht ein
Unit-Test). Das gilt als Reproduktion, weil er lokal nicht auslösbar ist (siehe unten) und der Zustand aus dem Lauf vollständig
belegt ist. Der Zustand „Fehler da“ ist der Lauf 39457247533 (rot); „Fehler weg“ ist AC-6 (fünf reguläre Läufe nach dem Fix grün plus der sechste Beleglauf mit `-only-testing` auf den Kalender-Test grün).

**Nachgestellt:** lokal nicht auslösbar (3 Läufe auf frischem Wegwerf-Simulator, alle grün; Lauf 3 mit künstlich kurzer Frist
bestätigt nur, dass der Handler auf einem ruhigen Mac fängt). Das Verhalten hängt von Last und Zeitablauf ab. Beleg „Fehler
weg“ kann deshalb nur aus der CI kommen (AC-6).

**Ohne Modell:** reine Testumgebung, kein Sprachverstehen.

**Alternativen:**
- **Weg B:** Hinweis aus wie oben, Dialog bleibt, der Test sucht ihn mit langer Frist direkt in SpringBoard und tippt „Allow Full
  Access“. Der Dialogpfad bliebe in der CI durchgespielt. Verworfen: bleibt fristabhängig (Ursache 4) und hängt an genau der
  Umgehung, die Apple selbst als anfällig nennt.
- **Weg C:** nur das Timeout von 3 s auf 30 s. Verworfen: Ursachen 1 und 3 bleiben, die Suite kann weiter kippen.
- Gewählt ist **Weg A**: Der Simulator wird vor dem ersten Test so vorbereitet, dass weder Hinweis noch Dialog erscheinen, in
  CI und lokal durch dasselbe Skript. Kippt keinen ADR. Gekippt wird nur die Annahme aus #203 im Test-Kommentar.

**Bewusste Folge von Weg A:** Der Systemdialog „Allow … to access your calendar?“ wird in der CI nicht mehr durchgespielt. Er ist
Apples Dialog; die App ruft nur `requestFullAccessToEvents()`. Alle Kalender-Tests prüfen weiter, was die App danach tut
(Zielkalender anlegen, anzeigen, wechseln).

## Source

- **File:** `.github/workflows/ci.yml` (Job `ui-smoke`, nach „Wait until the simulator has finished booting“)
- **Identifier:** `cmd_boot` in `scripts/sim.sh`; `allowCalendarAccessIfAsked` in `LooseEndsUITests/CalendarTargetTests.swift`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `xcrun simctl privacy <udid> grant calendar <bundle-id>` | werkzeug | erteilt die Kalender-Berechtigung vorab; geprüft ist nur, dass der Befehl auf einem frischen iOS-27-Simulator ohne installierte App mit Exit 0 endet (2026-10-21), nicht dass die Berechtigung die Installation übersteht (AC-7) |
| `xcrun simctl spawn <udid> defaults write com.apple.keyboard.preferences DidShowContinuousPathIntroduction -bool true` | werkzeug | schaltet den Tastatur-Hinweis ab (bestehende Zeile aus #341) |
| `scripts/test_sim_lock.py` | test | enthält `KeyboardHintTests` für `cmd_boot`; wird auf das neue Skript umgestellt |
| `LooseEnds/Calendar/CalendarBridge.swift` | code | `ensureAccess()` fragt nur, wenn der Status offen ist; unverändert |
| Bundle-ID `com.henning.looseends` | konstante | die UI-Tests starten die Hauptkennung (nicht „LE Prüfbau“) |

## Scope

| Datei | Änderung | Beschreibung |
|---|---|---|
| `scripts/sim_prepare.sh` | CREATE | `sim_prepare.sh <udid> [bundle-id]` (Vorgabe `com.henning.looseends`): Tastatur-Hinweis aus, Kalender-Zugriff für `com.henning.looseends` erteilen; Fehler laut, Exit ≠ 0 |
| `.github/workflows/ci.yml` | MODIFY | Schritt „Prepare the simulator“ im Job `ui-smoke`, nach dem Boot-Warten, vor dem Testlauf; ruft nur das Skript auf (die Beleg-Zeile im Log kommt vom Skript) |
| `scripts/sim.sh` | MODIFY | `cmd_boot` ruft `sim_prepare.sh` statt der Einzelzeile |
| `scripts/test_sim_lock.py` | MODIFY | `KeyboardHintTests` prüfen das Skript; neuer Test: `ci.yml` ruft es vor dem Testlauf auf |
| `LooseEndsUITests/CalendarTargetTests.swift` | MODIFY | Nur der Kommentar zu `allowCalendarAccessIfAsked` wird berichtigt; Rückfall und Monitor bleiben |

Geschätzt ca. +60/−8 LoC, 5 Dateien (Grenze 4–5 eingehalten). Keine Produktänderung, keine Berechtigungen im Produkt, keine
AppStorage-Schlüssel, keine Info.plist. **Geräteliste:** Kein Pfad der Geräteliste berührt (`project.yml`, Entitlements und
Info.plist bleiben unverändert). Nichts läuft auf Hennings Geräten. Keine sichtbare UI-Änderung, also kein Entwurf nötig.

## Definition of Done

- [ ] Simulator-Vorbereitung als ein gemeinsames Skript für CI und `sim.sh boot` (AC-1, AC-2, AC-3)
- [ ] Skript und Aufrufstellen durch Skripttests abgesichert (AC-4)
- [ ] Beleg, ob die vorab erteilte Berechtigung die App-Installation übersteht, steht im Ticket (Implementation Details 5, AC-7)
- [ ] Simulator-Stufe: frischer Wegwerf-Simulator, `sim.sh boot` mit Vorbereitung, `CalendarTargetTests` als erster Lauf grün ohne Dialog, Screenshot des Kalender-Schalters angesehen (AC-5)
- [ ] Beweis aus der CI: 5 reguläre Läufe grün, dazu ein eigener Beleglauf, in dem der Kalender-Test als erster und einziger Test nach frischem Simulator grün ist; Schritt-Log jedes Laufs zeigt Hinweis und Berechtigung gesetzt (AC-6)
- [ ] Alle Skripttests in `scripts/` und alle UI-Tests des Jobs grün

## Implementation Details

1. **`scripts/sim_prepare.sh <udid> [bundle-id]`** (ausführbar, `set -euo pipefail`): schreibt `DidShowContinuousPathIntroduction` und
   erteilt `simctl privacy grant calendar com.henning.looseends`. Jeder Fehler beendet mit Exit ≠ 0 und Meldung; kein
   `|| true`. Bundle-ID als zweiter, optionaler Parameter mit der Hauptkennung als Vorgabe. Erst wenn beide Befehle gelungen
   sind, gibt das Skript genau eine Zeile aus: `Simulator prepared: keyboard hint off, calendar access granted for <bundle-id> (<udid>)`.
   Sie ist der Beleg im CI-Log (AC-6); der CI-Schritt ruft das Skript nur auf und fügt nichts hinzu.
   **Beleglauf für AC-6 (feste Regel):** Der Beleglauf ist immer ein eigener, sechster Lauf und zählt nicht zu den fünf
   regulären. Er läuft auf einem vorübergehenden Commit auf dem PR-Zweig, der den Testlauf auf
   `-only-testing:LooseEndsUITests/CalendarTargetTests/testDefaultCalendarIsStampedOnSwitchOn` beschränkt, damit dieser Test
   sicher der erste und einzige ist; der Commit wird vor dem Merge zurückgenommen. Ohne grünen Beleglauf ist AC-6 nicht erfüllt.
2. **CI:** eigener Schritt, ruft `scripts/sim_prepare.sh "$SIM_UDID"`; schlägt der Aufruf fehl, bricht der Job vor dem Testlauf ab.
3. **`cmd_boot`:** ruft das Skript; bei Fehler weiter nur Warnung wie heute (lokale Läufe sollen nicht an der Vorbereitung
   scheitern), die CI dagegen bricht ab.
3a. **Skripttests (`scripts/test_sim_lock.py`):** `KeyboardHintTests` prüfen statt der Einzelzeile in `cmd_boot` das Skript und
   dessen Aufruf in `cmd_boot`; ein neuer Test liest `ci.yml` und prüft, dass im Job `ui-smoke` der Schritt mit
   `scripts/sim_prepare.sh "$SIM_UDID"` nach dem Boot-Warten und vor „Run UI smoke tests“ steht. Einzelheiten im Test Plan.
4. **Test:** `allowCalendarAccessIfAsked` bleibt als Rückfall (Frist 3 s), der Monitor bleibt. Kommentar wird richtiggestellt
   („Apple: Handler sieht SpringBoard-Alerts nicht zuverlässig; der Dialog wird per `simctl privacy` vorab verhindert“). Ein
   eigener Fehlerpfad für einen stehenden Dialog kommt nicht dazu: Er wäre nur mit einem echten stehenden Alert prüfbar, den der
   Aufbau gerade verhindert; der Fall ist über AC-6 abgesichert.
5. **Ein Weg; Beleg vor dem ersten CI-Lauf noch ausstehend (AC-7):** Die Berechtigung wird immer vor dem Testlauf erteilt, denn `xcodebuild test`
   baut und installiert in einem Befehl; einen Zeitpunkt „nach der Installation“ gibt es im Job nicht. Der Beleg auf einem
   frischen Wegwerf-Simulator (erteilen, App durch einen echten Testlauf installieren lassen, Dialog bleibt aus) kommt als
   Kommentar ins Ticket. Zeigt er den Dialog doch, ist diese Spec widerlegt: die Umsetzung hält an und die Spec wird neu
   geschrieben (Rücksprung nach Phase 3); es gibt keinen vorgeplanten zweiten Weg.

## Test Plan

| Test | Datei | Prüft |
|---|---|---|
| `test_prepare_script_sets_hint_and_grants_calendar` | `test_sim_lock.py` | Skript enthält beide Befehle, Fehler werden nicht verschluckt, bei Erfolg genau die Beleg-Zeile „Simulator prepared: …“ (AC-1, AC-2, AC-6) |
| `test_prepare_script_fails_loudly` | `test_sim_lock.py` | Stub-`xcrun` mit Fehler: Exit ≠ 0 und Meldung (AC-2) |
| `test_boot_uses_prepare_script` | `test_sim_lock.py` | `cmd_boot` ruft es nach `bootstatus` (AC-3) |
| `test_ci_prepares_simulator_before_tests` | `test_sim_lock.py` | `ci.yml`, Job `ui-smoke`: Schritt steht nach dem Boot-Warten und vor dem Testlauf, ruft das Skript mit `$SIM_UDID` (AC-4) |
| `CalendarTargetTests` (alle drei) | UI-Test | laufen auf frischem Simulator mit Vorbereitung ohne Dialog grün; lokal als Simulator-Stufe (AC-5) |
| CI-Beleg: 5 Läufe `UI Smoke` plus Beleglauf | CI | fünf reguläre Läufe beim ersten Versuch grün; ein sechster, eigener Lauf mit nur dem Kalender-Test; Schritt-Log jedes Laufs zeigt die Vorbereitung (AC-6) |
| Beleg Berechtigung nach Installation | Wegwerf-Simulator | Dialog bleibt aus, Ergebnis im Ticket (AC-7) |

Skripttests werden zuerst rot geschrieben (Skript fehlt, `ci.yml` ruft nichts auf). Der UI-Teil ist in der CI nur an
einem Lauf mit Last zu beweisen (siehe Purpose, „Nachgestellt“).

## Acceptance Criteria

- **AC-1:** Given ein frischer iOS-Simulator, When `scripts/sim_prepare.sh <udid>` läuft, Then ist `DidShowContinuousPathIntroduction` gesetzt und die Kalender-Berechtigung für `com.henning.looseends` erteilt; das Skript endet mit Exit 0.
- **AC-2:** Given einer der beiden Befehle schlägt fehl, When das Skript läuft, Then endet es mit Exit ≠ 0 und nennt, welcher Befehl scheiterte; nichts wird verschluckt.
- **AC-3:** Given `./scripts/sim.sh boot`, When der Simulator gestartet ist, Then ruft `cmd_boot` dasselbe Skript (kein zweiter Ort für die Einstellung).
- **AC-4:** Given der Job `ui-smoke`, When er läuft, Then führt er das Skript nach dem Boot-Warten und vor dem Testlauf aus und bricht bei Fehler vor dem Testlauf ab; `scripts/test_sim_lock.py` prüft diese Reihenfolge.
- **AC-5:** Given `CalendarTargetTests` auf einem so vorbereiteten, frischen Simulator, When der erste Test den Kalender einschaltet, Then erscheint kein Systemdialog und alle drei Tests sind grün.
- **AC-6:** Given der Job `UI Smoke` in der CI (jeder Lauf bootet einen frischen Simulator), When er fünfmal läuft, Then sind alle fünf Läufe beim ersten Versuch grün, das Schritt-Log jedes Laufs enthält die Zeile „Simulator prepared: keyboard hint off, calendar access granted for com.henning.looseends (<udid>)“, und in einem zusätzlichen, sechsten Beleglauf (Implementation Details 1), der nur `testDefaultCalendarIsStampedOnSwitchOn` ausführt, ist dieser Test als erster und einziger Test auf dem frischen Simulator grün; fehlt dieser grüne Beleglauf, ist AC-6 nicht erfüllt.
- **AC-7:** Given ein frischer Wegwerf-Simulator, When die Berechtigung vorab erteilt und die App danach durch `xcodebuild test` frisch installiert wird, Then bleibt der Kalender-Dialog aus, und das Ergebnis steht als Kommentar im Ticket.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Testumgebung, keine Architekturwirkung auf das Produkt; gekippt wird nur die Annahme im Test-Kommentar aus #203, keine ADR.

## Risiken

- **CI-Konfiguration wirkt auf alle UI-Tests**, Risiko MEDIUM: die Vorbereitung ist klein, fehlerlaut und läuft vor dem Testlauf.
- **Berechtigung hält die App-Installation nicht aus:** siehe Implementation Details 5 und AC-7; in dem Fall ist die Spec widerlegt und wird neu geschrieben.
- **Stehender Alert ohne eigenen Fehlerpfad:** Sollte doch einmal ein Dialog stehen, zeigt es sich als Testfehler samt Bild der Aufzeichnung wie bisher; ein gesonderter Test dafür ist nicht herstellbar (siehe Implementation Details 4).
- **Kein Dialog-Test mehr in der CI:** bewusst (siehe Purpose). Der Dialog bleibt Teil der Abnahme im Simulator bei Änderungen an `CalendarBridge`.
- **Beweis nur aus der CI:** lokal nicht auslösbar; AC-6 verlangt deshalb fünf reguläre CI-Läufe plus den sechsten Beleglauf, nicht einen grünen Lokallauf.

## Changelog

- 2026-10-21: Spec erstellt (Weg A: gemeinsame Simulator-Vorbereitung).
