# Adversary Dialog — fix-578-ui-test-kaltstart
Spec: docs/specs/tooling/fix-578-ui-test-kaltstart.md
Datum: 2026-10-21 08:36

## Checkliste
- [x] **AC-1:** Given ein frischer iOS-Simulator, When `scripts/sim_prepare.sh <udid>` läuft, Then ist `DidShowContinuousPathIntroduction` gesetzt und die Kalender-Berechtigung für `com.henning.looseends` erteilt; das Skript endet mit Exit 0.
- [x] **AC-2:** Given einer der beiden Befehle schlägt fehl, When das Skript läuft, Then endet es mit Exit ≠ 0 und nennt, welcher Befehl scheiterte; nichts wird verschluckt.
- [x] **AC-3:** Given `./scripts/sim.sh boot`, When der Simulator gestartet ist, Then ruft `cmd_boot` dasselbe Skript (kein zweiter Ort für die Einstellung).
- [x] **AC-4:** Given der Job `ui-smoke`, When er läuft, Then führt er das Skript nach dem Boot-Warten und vor dem Testlauf aus und bricht bei Fehler vor dem Testlauf ab; `scripts/test_sim_lock.py` prüft diese Reihenfolge.
- [x] **AC-5:** Given `CalendarTargetTests` auf einem so vorbereiteten, frischen Simulator, When der erste Test den Kalender einschaltet, Then erscheint kein Systemdialog und alle drei Tests sind grün.
- [ ] **AC-6:** Given der Job `UI Smoke` in der CI (jeder Lauf bootet einen frischen Simulator), When er fünfmal läuft, Then sind alle fünf Läufe beim ersten Versuch grün, das Schritt-Log jedes Laufs enthält die Zeile „Simulator prepared: keyboard hint off, calendar access granted for com.henning.looseends (<udid>)“, und in einem zusätzlichen, sechsten Beleglauf (Implementation Details 1), der nur `testDefaultCalendarIsStampedOnSwitchOn` ausführt, ist dieser Test als erster und einziger Test auf dem frischen Simulator grün; fehlt dieser grüne Beleglauf, ist AC-6 nicht erfüllt.
- [x] **AC-7:** Given ein frischer Wegwerf-Simulator, When die Berechtigung vorab erteilt und die App danach durch `xcodebuild test` frisch installiert wird, Then bleibt der Kalender-Dialog aus, und das Ergebnis steht als Kommentar im Ticket.

## Dialog

### Runde 1
**Adversary:** Tests selbst ausgefuehrt: `python3 -m unittest scripts.test_sim_lock -v` -> "Ran 32 tests in 48.674s / OK" (docs/artifacts/fix-578-ui-test-kaltstart/adversary-test-output.txt); `bash -n scripts/sim_prepare.sh scripts/sim.sh` -> OK. 0 uebersprungen.
(a) set -euo pipefail, jeder der zwei Befehle hat `|| { echo ...; exit 1; }`, keine Pipe, keine Subshell; Beleg-Zeile steht erst nach beiden. Kein Erfolgsweg bei Fehler.
(b) ci.yml: Schritt ohne continue-on-error und ohne `|| true`; Standard-Shell auf macOS-Runnern ist `bash -e`, zusaetzlich set -e im Skript. Schritt steht nach "Wait until the simulator has finished booting" und vor "Run UI smoke tests".
(c) Der Diff trifft nur ui-smoke; kein anderer Job beruehrt.
(d) scripts/sim_prepare.sh ist auf Platte 755, aber UNVERSIONIERT (Status `??`, nicht im Index). Die CI ruft es direkt per Pfad auf, braucht also +x im Index. Ohne Aufnahme mit Modus 100755 fehlt das Skript in der CI, und der bereits committete test_sim_lock.py ist rot.
(e) cmd_boot: `[ "$SIM_OS" = "iOS" ] && {...}` ist nicht die letzte Zeile (danach `success`); ein Nicht-iOS-Lauf loest set -e in einer &&-Liste nicht aus; Form wie vorher. Fehler der Vorbereitung wird per `|| warn` laut gemeldet.
(f) Bundle com.henning.looseends = PRODUCT_BUNDLE_IDENTIFIER der App (project.yml:118, BUNDLE_ID_SUFFIX leer), UI-Tests starten diese App. Dienst `calendar` ist der volle Zugriff; Bild 8EEBCC1B...png (selbst geoeffnet) zeigt Schalter "Show in calendar" an, Zielkalender "Calendar", Termin, kein Dialog.
(g) Tests pruefen Wirkung: Stub-xcrun protokolliert exakte Aufrufe, Exit-Code, genau eine Beleg-Zeile, Fehlerfall je Befehl mit Meldung und ohne Beleg-Zeile, fehlende UDID ohne Aufruf. Mutationen im Kopf (exit 1 entfernt, falsche Bundle-ID, Beleg-Zeile vorab, Aufruf in cmd_boot entfernt) -> jeweils rot. Schwaeche: CI-Test prueft nur `|| true` in der Zeile, nicht `continue-on-error`, und ein fehlender Marker (find=-1) liesse assertLess(wait, prepare) vakuum bestehen.
**Implementierer:** (nicht beteiligt, Kontext isoliert)

### Runde 2
**Adversary:** Nachgebohrt: simulator-run.txt: frischer Simulator LE-578-fresh, 3 gesamt, 3 bestanden, 0 fehlgeschlagen, 0 uebersprungen, `** TEST SUCCEEDED **`; summary.json passedTests 3, testFailures []. Ticket-Kommentar AC-7 vorhanden. Einschraenkung: der Lauf entstand mit nicht versioniertem sim_prepare.sh im Arbeitsbaum (Basis 314525e). Rote Ausgangslage (test-red-output.txt, Lauf 39457247533) vorhanden. AC-6: kein CI-Lauf mit dem Schritt, nicht belegt, nichts erfunden. Sonst nichts gefunden, das Erfolg bei Fehler vortaeuscht.
**Implementierer:** (nicht beteiligt)

### Runde 3
**Adversary:** Nachpruefung der Behebungen. F001: `ls-files -s` zeigt 100755 fuer scripts/sim_prepare.sh, Datei ist im Index (5 Dateien gestaged, +38/-6). F002: Diff in scripts/test_sim_lock.py:260 ergaenzt assertGreaterEqual fuer die Marker "Wait until..." und "Run UI smoke tests" sowie eine Blockpruefung des Schritts "Prepare the simulator" auf `continue-on-error` und `|| true`; der Schrittblock enthaelt beides nicht, Test besteht. Suite erneut: "Ran 32 tests in 48.299s / OK", 0 uebersprungen (adversary-test-output.txt aktualisiert). F001 und F002 sind behoben. AC-6 bleibt offen (F003), nur aus der CI belegbar.
**Implementierer:** F001/F002 behoben (laut Orchestrator).

## Findings und Confirmations

Finding:
  ID: F001 (BEHOBEN in Runde 3, Index 100755)
  Severity: MEDIUM
  Category: regression
  Code reference: scripts/sim_prepare.sh:1
  Description: Datei ist nicht im Index (Status `??`); nur auf Platte 755. CI ruft sie direkt per Pfad auf.
  Spec requirement: AC-4 — Job fuehrt das Skript aus und bricht bei Fehler ab
  Conflict: Ohne Aufnahme mit Modus 100755 fehlt das Skript bzw. ist nicht ausfuehrbar; CI-Schritt scheitert, committeter test_sim_lock.py ist rot.
  Remediation: vor dem Commit Datei stagen und Modus 100755 im Index pruefen (oder in ci.yml `bash scripts/sim_prepare.sh`).

Finding:
  ID: F002 (BEHOBEN in Runde 3)
  Severity: LOW
  Category: edge_case
  Code reference: scripts/test_sim_lock.py:260
  Description: test_ci_prepares_simulator_before_tests prueft kein continue-on-error am Schritt und besteht vakuum, wenn der Marker "Wait until..." fehlt (find=-1).
  Spec requirement: AC-4 — Test prueft Reihenfolge, Abbruch bei Fehler
  Conflict: Absicherung schwaecher als behauptet.
  Remediation: assertGreaterEqual(wait, 0) und assertNotIn("continue-on-error", Schrittblock) ergaenzen.

Finding:
  ID: F003
  Severity: HIGH
  Category: spec_violation
  Code reference: .github/workflows/ci.yml:147
  Description: Schritt vorhanden, aber noch kein CI-Lauf.
  Spec requirement: AC-6 — fuenf gruene CI-Laeufe mit Log-Zeile plus sechster Beleglauf
  Conflict: Nicht belegt (offen, nur aus der CI nach Push). Kein Defekt, aber unbewiesen.
  Remediation: Gate fuehrt AC-6 als "offen bis CI" (Belege aus den Laeufen ins Ticket), nicht als erfuellt.

Confirmation:
  AC: AC-1
  Code reference: scripts/sim_prepare.sh:14
  Evidence: defaults write und privacy grant calendar, Exit 0; Test sets_hint_and_grants_calendar gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/sim_prepare.sh:16
  Evidence: je Befehl `|| { echo ... >&2; exit 1; }`, set -euo pipefail; fails_loudly gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/sim.sh:521
  Evidence: cmd_boot ruft sim_prepare.sh, keine zweite Einstellung; test_boot_uses_prepare_script gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: .github/workflows/ci.yml:147
  Evidence: Schritt zwischen Boot-Warten und Testlauf, ohne continue-on-error/|| true, bash -e (bedingt durch F001).
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEndsUITests/CalendarTargetTests.swift:258
  Evidence: simulator-run.txt 3/3 bestanden, Bild ohne Dialog; nur Kommentar geaendert.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/test_sim_lock.py:196
  Evidence: Ticket-Kommentar AC-7, frischer Simulator, Installation durch xcodebuild test, kein Dialog.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: AMBIGUOUS
AC-1 bis AC-5 und AC-7 bewiesen (6/7). AC-6 nicht belegt (nur CI nach Push). F001 und F002 behoben. AC-6 extern nachzureichen (CI-Belege).
Tests: 32 passed, 0 failed, 0 uebersprungen

## Geprüfte Dateien

- sha256:2b698b46d3bc1d71dc6366630a8af86f31432b2f4dd8b7c8b143f35f93878451  .github/workflows/ci.yml
- sha256:f324f73142dc781495b7fa5dac19d0524e5723f9ed36547e287fa831c8c0fdba  LooseEndsUITests/CalendarTargetTests.swift
- sha256:f24b18efe290f3cc85d1def7bc6913e33c4627d7c6fb5943a6e3311a4c091889  scripts/sim.sh
- sha256:353dd30399062d4d6fa9ad80390e09f999edacc186de6e380de9acf89e01ea4b  scripts/sim_prepare.sh
- sha256:79745bee8dc3066ad3f37316132622c741148bdc5a6f2ab40329c694f98c514f  scripts/test_sim_lock.py

## Prüfbasis

- base: 6ce15a05448b2ed277eb80a4a876621eda8d402c
- blob:c2db6c9a49b48729f2f8036915f932dd57e3853d  .github/workflows/ci.yml
- blob:3b7c3acbd903435f06439a08a6771044ad615e99  LooseEndsUITests/CalendarTargetTests.swift
- blob:fdfe323fcc62f2f8fecc10331705b3ec8fd89b79  scripts/sim.sh
- blob:99a8708317c02382eb21488624f3b2a7727622c7  scripts/sim_prepare.sh
- blob:a7b795c404349ce7d92fd1c0648b2ff0be9a0a90  scripts/test_sim_lock.py
