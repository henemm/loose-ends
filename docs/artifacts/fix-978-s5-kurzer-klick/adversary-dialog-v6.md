# Adversary Dialog — fix-978-s5-kurzer-klick
Spec: docs/specs/fix-978-s5-kurzer-klick.md
Datum: 2026-11-25 17:39

## Checkliste
- [x] **AC-1:** Given `scripts/test_mac_panel_repeat_summary.py` / When `python3 -m unittest` lokal läuft / Then sind alle Skripttests grün, darunter neue Tests, die `retry: hold X s` in Anhängen erkennen und je Arm Wiederholungen, deren Haltedauer und das Ergebnis des zweiten Klicks zählen; eine Iteration mit Wiederholung und offenem zweitem Klick zählt nicht als rot und wird ausgewiesen, eine mit zweitem Fehlschlag zählt als rot. Belegt durch den Testlauf.
- [x] **AC-2:** Given `scripts/test_mac_reopen_settle.py` / When er lokal läuft / Then ist er grün und verlangt: genau ein Retry-Pfad in `MacGalleryTests.swift` mit Schwelle `0.4`, höchstens eine Wiederholung, kein Retry ohne gelesene Haltedauer (unter 0,4 s, „kurz“ und „unbekannt“ sind hart rot mit Haltedauer oder Grund in der Meldung), Klick weiter `shortClick` mit `click(forDuration: 0.1`. Belegt durch den Testlauf.
- [x] **AC-3:** Given `LooseEndsUITests/MacPanelHold.swift` / When `test_mac_reopen_settle.py` den Quelltext prüft / Then enthält der Helfer `OSLogStore`, Subsystem `com.henning.looseends`, Kategorie `MenuBarPanel`, die Paarung erste `panel key`-Zeile nach dem Klick mit erstem Maus-hoch (`type=2`) im 3-s-Fenster, und die Ergebnisse „kurz“ und „unbekannt“ mit Grund. Belegt durch den Testlauf und den Diff.
- [x] **AC-4:** Given der Diff dieses Schnitts / When `git diff --stat` gegen den Ausgangsstand geprüft wird und das UI-Test-Bundle per Build-Prüfung übersetzt wird / Then ist App-Code (`LooseEnds/`) unverändert (0 LoC), ebenso `project.yml`, `ci.yml`, `mac-panel-repeat.yml` und jede Gate-Konfiguration, der Schnitt liegt bei höchstens 5 Dateien, das Bundle übersetzt ohne Fehler (die neue Datei kommt über die Ordnerquelle `LooseEndsUITests` ins Bundle), Kontrollarm und Halteprobe bleiben mit Umgebungsvariable und `XCTSkip`. Belegt durch `git diff --stat` und Prüfausgabe.
- [ ] **AC-5:** Given der Halteprobe-Lauf `mac-panel-repeat.yml` mit `halteprobe=true` / When er endet und die Anhänge geöffnet werden / Then steht in den Anhängen je Klick die vom Helfer gelesene Haltedauer, und die 1,0-s-Klicks zeigen Werte ≥ 0,4 s. Fehlt jede gelesene Haltedauer oder ist sie durchgängig „unbekannt“, gilt Abbruchregel (a): Stopp, A-ax per Spec-Nachtrag, AC-6 und AC-7 werden nicht angegangen. Belegt durch Lauf-Kennung und geöffneten Anhang in der Beleg-Datei unter `docs/artifacts/fix-978-s5-kurzer-klick/`.
- [ ] **AC-6:** Given der Nachweislauf `mac-panel-repeat.yml` mit `iterationen=40` und beiden Nutzerarmen (`ReturnWithOneClick`, `OpenAppWithOneClick`) / When er endet und ausgewertet wird / Then liegen je Arm 40 Iterationen vor, 0 sind rot, jede Wiederholung trägt eine gelesene Haltedauer ≥ 0,4 s, und Lauf-Kennung, Zähler, Wiederholungen mit Haltedauer und Rate stehen in einer Beleg-Datei unter `docs/artifacts/fix-978-s5-kurzer-klick/`. Tritt ein Panel-zu-Fall mit Haltedauer unter 0,4 s oder ein zweiter Fehlschlag nach Wiederholung auf, gilt Abbruchregel (b): Stopp, neue Analyse, AC-7 wird nicht angegangen. Belegt durch die Artefakte, geöffnet und beschrieben.
- [ ] **AC-7:** Given der Stand dieses Schnitts im Pull Request, vor dem Merge / When der Job „Mac Gallery (macOS)“ dreimal hintereinander auf demselben Commit grün läuft (Lauf 45642824480 zählt nicht, anderer Stand) / Then stehen die drei Lauf-Kennungen in der Beleg-Datei unter `docs/artifacts/fix-978-s5-kurzer-klick/` und im Issue #978 (DoD von #978). Belegt durch die CI-Läufe.

## Dialog

### Runde 1
**Adversary:** Skripttests selbst gelaufen (`adversary-test-output.txt`): 118 Tests, OK, 0 uebersprungen (die zwei Treffer auf "skip" sind die Testnamen `test_no_skip` und `test_stress_runs_skip_the_600_second_diagnostics`, beide ok). Uebersetzungsbeleg `build-check-v6.txt`: TEST BUILD SUCCEEDED, 0 `error:`. Der Diff gegen 33a102b fuer LooseEnds, project.yml und .github ist leer.
Randfaelle am Auswerter probiert: `parse_retry` liest `retry: hold 0.616 s`, `0.4`, `0.399`; `retry: hold s` (ohne Zahl) gibt None, bei zwei Zeilen gilt die erste; eingerueckte Zeile gibt None.
Swift-Quelle: genau ein Retry-Pfad `retryAfterLongHold` (MacGalleryTests.swift:648), Schwelle `held >= Self.retryHold` mit 0.4 (Zeile 635/651), Retry nur im Fall `.seconds`; `.short` und `.unknown` liefern kein zweites Klicken. Kein `try?`, kein `print`, keine Schleife um den Klick. `clickedAt` wird VOR dem Klick genommen (MacGalleryTests.swift:318). Kontrollarm: Bedingung `click == nil`, also nie Wiederholung; die Spec deckt das (Kontrollarm bleibt). Das Fenster in `MacPanelHold.hold` (`offset >= 0 && offset < window`, 3 s) ist halboffen wie `0 <= ... < MONITOR_SECONDS` im Auswerter (mac_panel_repeat_summary.py:256).
**Implementierer:** (nicht beteiligt; Kontextisolation)

### Runde 2
**Adversary:** Tiefer: (1) `retry` ohne Zahl im Anhang: der Auswerter zaehlt beide Klicks als Iterationen (n 41, erster Fehlschlag bleibt rot), konservativ, nie zu gruen (F001, LOW). (2) Schwelle `>=`: genau 0.400 wiederholt, 0.399 nicht; `test_retry_only_on_read_seconds_at_or_above_threshold` (test_mac_reopen_settle.py:193) haelt das. (3) Der zweite Klick wird weder erneut gelesen noch wiederholt: `seen = watch(second.at)` ohne weiteren Retry, hart. (4) Das Auslesen geschieht nach 3 bis 13 s, der Monitor endet 3 s nach `key`. Ob der Laeufer `OSLogStore.local()` lesen darf, ist unbelegt und Gegenstand von AC-5, lokal nicht beweisbar. (5) Lesefehler gibt `.unknown`, hart rot mit Grund, kein verdeckter Erfolg. (6) Laufzeitverhalten (Sandbox, Protokollzugriff) nur in CI pruefbar.
AC-5 bis AC-7 verlangen CI-Laeufe nach Push, die es nicht gibt; nicht erfunden, offen.
**Implementierer:** (nicht beteiligt)

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: scripts/mac_panel_repeat_summary.py:101
  Description: `parse_retry` verlangt eine Zahl; ein Anhang mit `retry: hold s` wird als normaler Klick gezaehlt, die Iteration doppelt (n 41), der erste Fehlschlag bleibt rot.
  Spec requirement: AC-1 / AC-6 - je Arm 40 Iterationen
  Conflict: nur konservativ (nie zu gruen), Swift schreibt immer eine Zahl; keine Auswirkung im Normalfall.
  Remediation: optional Abweichung in `deviations` melden.

Confirmation:
  AC: AC-1
  Code reference: scripts/test_mac_panel_repeat_summary.py:764
  Evidence: neue Tests fuer Retry offen/zu/ohne Retry laufen gruen (118 OK); scripts/mac_panel_repeat_summary.py:138 (iterations), :149 (retries), :333 (retry_report) ersetzen den ersten Klick durch den zweiten und weisen Wiederholungen aus.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/test_mac_reopen_settle.py:185
  Evidence: ein Retry-Pfad, `held >= Self.retryHold` (0.4) nur bei `.seconds` (LooseEndsUITests/MacGalleryTests.swift:651); shortClick mit `click(forDuration: 0.1` (MacGalleryTests.swift:629); Kontrollarm/Halteprobe hinter XCTSkip (MacGalleryTests.swift:501, 524); Tests gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEndsUITests/MacPanelHold.swift:53
  Evidence: OSLogStore.local(), Subsystem com.henning.looseends, Kategorie MenuBarPanel, erste `panel key`-Zeile, erstes `type=2` im 3-s-Fenster, Ergebnisse `.short` und `.unknown(reason)`; Tests test_mac_reopen_settle.py:233-253 gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEndsUITests/MacGalleryTests.swift:318
  Evidence: LooseEnds/, project.yml, .github gegen 33a102b unveraendert; 5 Dateien (MacPanelHold, MacGalleryTests, Auswerter, zwei Skripttests); Build-Beleg TEST BUILD SUCCEEDED.
  Status: CONFIRMED

Offen (nicht beweisbar ohne CI nach Push): AC-5 (Halteprobe-Lauf), AC-6 (Nachweislauf 40 je Arm), AC-7 (drei gruene Galerie-Laeufe auf demselben Commit).

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`).

## Verdict

═══════════════════════════════════════
VERDICT: AMBIGUOUS
═══════════════════════════════════════
Ambiguous findings (require human review):
  AC-5, AC-6, AC-7: verlangen CI-Laeufe nach Commit und Push (Halteprobe, Nachweislauf 40, drei gruene Galerie-Laeufe); noch nicht vorhanden, nicht erfunden. Ob der Testlaeufer OSLogStore.local() lesen darf, ist nur dort belegbar.
  F001 (LOW): retry ohne Zahl wird doppelt gezaehlt (konservativ).

Proven points: 4/7 (AC-1 bis AC-4)
Tests: 118 passed, 0 failed, 0 uebersprungen
Edge cases: geprueft, kein Defekt
Regressions: None found

## Geprüfte Dateien

- sha256:a1f136cf10e5ba0027344921895deaca9359965c5457d5beed4444e72492e5a2  LooseEndsUITests/MacGalleryTests.swift
- sha256:427eb6aabe94ced61b8310409126af15b7f987b5a1ad265daaaba3d1bc9e1360  LooseEndsUITests/MacPanelHold.swift
- sha256:bac20ccc204a073c04cb172ac732ea6c45556b2592c9cbf338e421806dfec09e  scripts/mac_panel_repeat_summary.py
- sha256:e7856abe52356357b5dd494b6ab1cd129690ee347db1fa22bb6a95f8af66b6a6  scripts/test_mac_panel_repeat_summary.py
- sha256:28a0f9170f0a23c60df58687b4360fd20f3ac495bfc3d8628f27353fcdc26d10  scripts/test_mac_reopen_settle.py

## Prüfbasis

- base: 33a102b76c8c000e05549636f4c9010a0e9916be
- blob:e435fa74826a663395b3050cf06fdff8192e55bb  LooseEndsUITests/MacGalleryTests.swift
- blob:7fc4ceb1bf00931e95de261f2ec8fa22c9b6543f  LooseEndsUITests/MacPanelHold.swift
- blob:ca53a416468525cafc792572ae530af96e9b0b47  scripts/mac_panel_repeat_summary.py
- blob:e0cfa1c43f0fe4ee1cc1dd249a588e206dd0fa93  scripts/test_mac_panel_repeat_summary.py
- blob:439951bfdaeca30261fa91371063b59f91a6459c  scripts/test_mac_reopen_settle.py
