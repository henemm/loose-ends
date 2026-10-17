---
entity_id: fix-341-testlaeufe-verlaesslich
type: bugfix
created: 2026-10-17
updated: 2026-10-17
status: draft
workflow: fix-341-testlaeufe-verlaesslich
---

# Spec: #341 — Testläufe verlässlich (mit #413 und #374)

## Approval

- [ ] Approved

## Purpose

Testbelege sollen verlässlich sein: UI- und Unit-Tests laufen lokal wie in der CI beim ersten Versuch grün, nie mit
Hennings Mac als Testhost, und parallele Sitzungen verfälschen einander nicht. #341 bündelt #208, #168, #305, #304
und #294; #413 (rechnerweite Sperre) und #374 (`unit` auf dem Mac) gehen hier auf. Henning hat am 2026-10-17 „ein
Ablauf“ gewählt. Es ändert sich kein Produktcode und nichts Sichtbares in der App; geändert werden `scripts/sim.sh`,
ein Kalender-UI-Test, ein neuer Skripttest und CLAUDE.md.

Ursachen (belegt, Details in `docs/context/fix-341-testlaeufe-verlaesslich.md`):

- **Sitzungen (#304):** `sim.sh` liest `CLAUDE_SESSION_ID`; Claude Code setzt dort nur `CLAUDE_CODE_SESSION_ID`. Alle
  Sitzungen fallen auf `default` zurück und teilen DerivedData `LooseEnds-session-default`. Die Sperre `LOCK_DIR` liegt je
  Worktree, sperrt also nicht über Worktrees hinweg, verfällt nach 600 s, und `build` und `unit` sperren gar nicht (#413).
- **Mac-Host (#294, #374):** `cmd_unit` nimmt `platform=macOS`, sobald macOS ≥ Deployment Target ist (heute 27.0.1 ≥ 27.0).
- **Lokal rot (#305):** `calendarTargetRow` liegt in der List unter dem Bildrand und wird erst nach einem Wischen
  erzeugt; im roten Lauf bewegte das eine Wischen die Liste nicht. `allowCalendarAccessIfAsked` wartet zudem in jedem
  Lauf 30 s auf diese unsichtbare Zeile. `ContextUniquenessTests` war in vier Läufen grün; die Hypothese
  `startShowsContexts` ist seit #428 auf dem iPhone überholt.
- **Teile 1 und 2 (#208, #168):** unter `--ui-testing` nimmt die App seit #228 `ModelOffEnricher`; kein Code, nur Belegläufe.

## Source

- **File:** `scripts/sim.sh`
- **Identifier:** `SESSION_ID`/`SESSION_DERIVED_DATA` (Zeile 54–55), `LOCK_DIR`/`acquire_lock` (56–80), `mac_hosts_tests` (167), `cmd_unit` (181), `cmd_sim_unit` (298), `cmd_test`/`cmd_test_proof` (308–363), `device_derived_data` (402), Kopfkommentar (1–38)
- **Weitere:** `LooseEndsUITests/CalendarTargetTests.swift` (fünf Stellen mit Ein-Wischen, `allowCalendarAccessIfAsked`)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `scripts/test_sim_run_xcodebuild.py` | test | Zieht `run_xcodebuild()` wörtlich aus `sim.sh`; Funktion nicht umbenennen, Sperre außerhalb davon |
| `scripts/test_sim_proof.py`, `scripts/sim_proof.py` | test | Kopiert `sim.sh` in ein Temp-Verzeichnis und ruft `test-proof`; Sperre dort per `LOOSEENDS_LOCK_DIR` umlenkbar |
| `LooseEndsUITests/StartScreenInteractionTests.swift` | test | Vorbild für `scrollTo` |
| `CLAUDE.md` | doc | Build-Abschnitt nennt `unit`, Sperre und Bauordner |
| #228 | spec | `ModelOffEnricher` unter `--ui-testing` (Teile 1, 2) |
| #172, #336 | spec | Gemeinsames Ziel „UI-Tests beim ersten Versuch grün“; #336 ist geschlossen und zählt nur für die DoD |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/sim.sh` | MODIFY | (C) `unit` im Simulator, Mac-Host nur mit `LOOSEENDS_MAC_HOST=1`, Kopfkommentar; (A) DerivedData-Schlüssel aus Worktree-Ordnername; (B) rechnerweite Sperre |
| `scripts/test_sim_lock.py` | CREATE | Skripttest für A, B, C |
| `LooseEndsUITests/CalendarTargetTests.swift` | MODIFY | (D) Helfer „scrollen bis Zeile da“, Zugriffsabfrage wartet auf die Systemabfrage |
| `CLAUDE.md` | MODIFY | Build-Abschnitt aktualisieren |
| `LooseEndsUITests/ContextUniquenessTests.swift` | — | unverändert, nur belegen |

### Estimated Changes

- Files: 4 (3 MODIFY, 1 CREATE)
- LoC: ca. +250/−20 (sim.sh ~70, Skripttest ~90, Kalendertest ~35, CLAUDE.md ~15)
- Rückfall: Reißt die Umsetzung die 250 LoC, wird Teil B (Sperre) als #413 abgetrennt und separat geliefert.
- Keine neuen Abhängigkeiten, Berechtigungen, AppStorage-Schlüssel oder Audiodateien.

## Definition of Done

- [ ] `unit` läuft im Simulator, Mac-Host nur per Schalter (AC-1, AC-2)
- [ ] Bauordner je Worktree, Override bleibt (AC-3, AC-4)
- [ ] Rechnerweite Sperre mit Verwaisungserkennung, Statuszeile, Obergrenze (AC-5 bis AC-10)
- [ ] Kalendertest gehärtet, nicht abgeschwächt (AC-11, AC-12)
- [ ] Belegläufe Teile 1, 2, 3 (AC-13 bis AC-15)
- [ ] Zwei Sitzungen gleichzeitig (AC-16)
- [ ] CLAUDE.md, Skripttests, Abnahme (AC-17 bis AC-19)

## Implementation Details

### Teil C — `unit` nur im Simulator (#294, #374)

`cmd_unit` wählt den Simulator wie `cmd_sim_unit`. Der Mac ist nur Testhost, wenn `LOOSEENDS_MAC_HOST=1` gesetzt ist
(dann greift weiter `mac_hosts_tests`). Der Kopfkommentar von `sim.sh` nennt statt „macOS-Destination“ den Simulator und
den Schalter. Der CI-Unit-Job ruft `xcodebuild` direkt auf GitHubs Rechner auf und ist nicht betroffen.

### Teil A — Bauordner je Worktree (#304)

Der DerivedData-Schlüssel ist der bereinigte Name des Worktree-Ordners (Basename von `PROJECT_DIR`, nur `[A-Za-z0-9._-]`,
Rest durch `-`). `CLAUDE_SESSION_ID` bleibt Override, wenn gesetzt. Fällt kein Ordnername ab (leer), bleibt `default`.
Auch `device_derived_data` nimmt denselben Schlüssel; die Ausgabe wird nicht mehr auf 8 Zeichen gekürzt. Neue Funktion
`session_key() {` … `}`, damit Skripttests sie herausziehen können.

### Teil B — rechnerweite Sperre (#413, löst Teil 4 von #304)

- Sperrverzeichnis `/tmp/loose-ends-testlauf.lock` (umlenkbar per `LOOSEENDS_LOCK_DIR`), angelegt per atomarem `mkdir`.
- Darin eine Datei `pid` mit PID, Startzeit des Prozesses (`ps -o lstart=`), Worktree und Befehl.
- Verwaist = PID tot oder Startzeit weicht ab (PID-Wiederverwendung). Eine Sperre ohne `pid`-Datei (Handsperre, z. B. von
  Hand angelegtes Verzeichnis) gilt erst nach langer Frist (30 min seit Änderungszeit) als verwaist.
- Übernahme atomar per `mv` des alten Verzeichnisses auf einen eindeutigen Namen, dann `rm -rf`, dann neues `mkdir`;
  verliert ein Lauf das Rennen, wartet er weiter.
- Reentrant: Ruft ein Befehl innerhalb desselben Prozessbaums einen weiteren gesperrten Befehl auf (zum Beispiel
  `test-proof` ruft `test`), blockiert er sich nicht selbst (Umgebungsvariable mit der Besitzer-PID).
- Wartend: alle 30 s eine Zeile mit Halter (Worktree, Befehl, PID). Obergrenze 30 min, danach Abbruch mit klarer Meldung.
- Freigabe über `trap EXIT`; die Sperre wird nur entfernt, wenn die `pid`-Datei dem eigenen Prozess gehört.
- Gesperrt werden `build`, `unit`, `sim-unit`, `test`, `test-proof`, `launch`, `mac-build`. `run_xcodebuild` bleibt
  unverändert benannt und enthält die Sperre nicht. Die alte Sperre `LOCK_DIR` je Worktree entfällt.
- Neue Funktionen `acquire_testlock() {`, `lock_is_stale() {`, `release_testlock() {`, jeweils mit schließender `}` in Spalte 0.

### Teil D — Kalendertest (#305)

In `CalendarTargetTests.swift` ein Helfer `scrollUntilVisible(_ element:)`: bis zu fünf langsame Wischversuche
(`swipeUp(velocity: .slow)`) auf die Liste (nicht auf `app`), nach jedem Versuch kurze Prüfung `element.exists`; bleibt die
Zeile aus, schlägt der Test mit klarer Meldung fehl („Zeile … nach 5 Wischversuchen nicht erzeugt“). Der Helfer ersetzt
die fünf Ein-Wischen-Stellen. `allowCalendarAccessIfAsked` wartet auf die Systemabfrage (`springboard`-Alert) mit kurzer
Frist statt 30 s auf die Zeile. Zusicherungen bleiben unverändert (nicht abgeschwächt).

### Teile 1, 2, 3a — nur Belege

Kein Code. `CaptureSmokeTests` zweimal, `RecognitionWalkthroughTests` dreimal, `ContextUniquenessTests` auf frischem und
benutztem Simulator über `./scripts/sim.sh test-proof <Klasse>`. Nach Beleg sind #208 und #168 im Ticket als durch #228 erledigt einzuordnen.

### Alternativen

1. Eigener geklonter Simulator je Worktree (`simctl clone`): verworfen, weil er die Last erhöht (7 Simulatoren, Last 260–370 am 2026-10-14) und mehr als 100 LoC braucht.
2. Schlüssel aus `CLAUDE_CODE_SESSION_ID`: wechselt bei jedem `/clear` (kalter Bau, wachsender Plattenverbrauch); nur Rückfall.
3. Nur Sperre, DerivedData bleibt gemeinsam: Bauten verschiedener Worktrees überschreiben einander weiter.
4. Kalenderzeile im Produkt nach oben setzen: verworfen, Produktänderung für einen Test.

## Test Plan

### Automated Tests (TDD RED)

`scripts/test_sim_lock.py` (läuft in der CI mit den anderen Skripttests, Funktionen werden wörtlich aus `sim.sh` gezogen):

- [ ] `test_session_key_from_folder_name` — Ordner `prancy-noodling-axolotl` ergibt Schlüssel `prancy-noodling-axolotl`; Sonderzeichen werden zu `-`.
- [ ] `test_session_key_override` — `CLAUDE_SESSION_ID=abc` gewinnt vor dem Ordnernamen.
- [ ] `test_unit_never_macos_without_switch` — `cmd_unit` enthält ohne `LOOSEENDS_MAC_HOST=1` kein `platform=macOS` (Destination-Ausgabe bei gestubbtem `xcodebuild`), mit Schalter schon.
- [ ] `test_two_runs_are_serialized` — zwei gleichzeitige Sperrversuche (Lock-Verzeichnis in Temp) laufen nacheinander, nicht überlappend.
- [ ] `test_orphan_lock_taken_over` — Halter per `kill -9` beendet; der nächste Lauf übernimmt ohne Wartezeit bis zur Obergrenze.
- [ ] `test_start_time_mismatch_is_orphan` — `pid` lebt, Startzeit weicht ab: verwaist.
- [ ] `test_hand_lock_without_pid_waits` — Verzeichnis ohne `pid` blockiert, bis die lange Frist verstrichen ist (Frist per Variable verkürzt).
- [ ] `test_reentrant` — verschachtelter Aufruf im selben Prozessbaum blockiert nicht.
- [ ] `test_wait_message_and_cap` — Statuszeile mit Halter erscheint; Obergrenze (per Variable verkürzt) bricht mit klarer Meldung ab.

UI-Testlauf-Belege (kein neuer Test, Belegläufe über `test-proof`): `CaptureSmokeTests` 2×, `RecognitionWalkthroughTests` 3×,
`ContextUniquenessTests` je auf frischem und benutztem Simulator, `CalendarTargetTests` mindestens 5× (ganze Klasse).

## Acceptance Criteria

- **AC-1:** Given ein Mac mit macOS ≥ Deployment Target, When `./scripts/sim.sh unit` ohne `LOOSEENDS_MAC_HOST` läuft, Then ist das Testziel ein iOS-Simulator mit Laufzeit ≥ 27.0 und `platform=macOS` kommt weder in der Ausgabe noch in der Destination vor (Skripttest `test_unit_never_macos_without_switch`).
- **AC-2:** Given `LOOSEENDS_MAC_HOST=1`, When `unit` läuft, Then wählt es den Mac als Host; der Kopfkommentar von `scripts/sim.sh` nennt den Simulator als Standard und den Schalter.
- **AC-3:** Given der Worktree-Ordner `prancy-noodling-axolotl` und kein `CLAUDE_SESSION_ID`, When `sim.sh` das DerivedData bestimmt, Then liegt es unter `LooseEnds-session-prancy-noodling-axolotl` (bereinigter Ordnername, nicht `default`); `device_derived_data` nutzt denselben Schlüssel (Skripttest `test_session_key_from_folder_name`).
- **AC-4:** Given `CLAUDE_SESSION_ID=abc`, When `sim.sh` den Schlüssel bestimmt, Then gewinnt `abc` (Skripttest `test_session_key_override`).
- **AC-5:** Given zwei gleichzeitig gestartete Läufe (zwei Worktrees), When beide eine gesperrte Aktion ausführen (`sim-unit`), Then laufen sie nacheinander; die Ausgabe des zweiten nennt den Halter (Worktree, Befehl, PID), und die Zeiträume beider Läufe überlappen nicht.
- **AC-6:** Given ein Lauf, der per `kill -9` beendet wurde, When der nächste Lauf startet, Then übernimmt er die Sperre sofort (Skripttest `test_orphan_lock_taken_over`), ebenso bei lebender PID mit abweichender Startzeit.
- **AC-7:** Given ein Sperrverzeichnis ohne `pid`-Datei, When ein Lauf startet, Then wartet er und übernimmt erst nach der langen Frist (30 min Standard, in der Prüfung verkürzt).
- **AC-8:** Given ein gesperrter Befehl, der innerhalb desselben Prozessbaums einen weiteren gesperrten Befehl ruft (`test-proof` → `test`), When er läuft, Then blockiert er sich nicht selbst.
- **AC-9:** Given ein belegter Halter, When ein Lauf wartet, Then erscheint alle 30 s genau eine Statuszeile mit Halter, und nach 30 min Wartezeit bricht er mit klarer Meldung und Exit-Code ≠ 0 ab.
- **AC-10:** Given `build`, `unit`, `sim-unit`, `test`, `test-proof`, `launch`, `mac-build`, When sie starten, Then holen alle die Sperre; `run_xcodebuild` ist unverändert benannt, enthält keine Sperre, und `scripts/test_sim_run_xcodebuild.py` sowie `scripts/test_sim_proof.py` bleiben grün (letzterer mit `LOOSEENDS_LOCK_DIR` im Temp-Verzeichnis).
- **AC-11:** Given `CalendarTargetTests`, When die Zeile unter dem Bildrand liegt, Then scrollt der Helfer mit bis zu fünf langsamen Wischversuchen auf die Liste, bis sie existiert, und schlägt sonst mit klarer Meldung fehl; alle fünf Ein-Wischen-Stellen nutzen ihn, die Zusicherungen sind unverändert.
- **AC-12:** Given `allowCalendarAccessIfAsked`, When keine Systemabfrage erscheint, Then kehrt die Funktion nach kurzer Frist zurück statt nach 30 s auf die Zeile zu warten (gemessen an der Laufzeit der Klasse im Protokoll).
- **AC-13:** `./scripts/sim.sh test-proof CaptureSmokeTests` ist zweimal und `RecognitionWalkthroughTests` dreimal hintereinander grün (maschineller Beleg, Screenshots geöffnet und beschrieben); #208 und #168 sind im Ticket als durch #228 erledigt eingeordnet.
- **AC-14:** `ContextUniquenessTests` ist auf einem frisch zurückgesetzten und auf einem benutzten Simulator grün.
- **AC-15:** `CalendarTargetTests` (ganze Klasse) ist mindestens fünfmal hintereinander auf dem benutzten Simulator grün, davon `testSwitchOnShowsTargetCalendar` jedes Mal; der Test ist nicht abgeschwächt.
- **AC-16:** Given zwei Worktrees, When beide gleichzeitig `sim.sh build` und `sim-unit` starten, Then zeigt keiner den Stand des anderen (je eigener DerivedData-Ordner) und die Läufe sind serialisiert; Beleg: beide Ausgaben im Bericht zitiert.
- **AC-17:** Der Build-Abschnitt in `CLAUDE.md` nennt: `unit` läuft im Simulator, Mac-Host nur mit `LOOSEENDS_MAC_HOST=1`, Sperre `/tmp/loose-ends-testlauf.lock`, Bauordner je Worktree; die Handabsprache per Sperrdatei ist als entfallen vermerkt.
- **AC-18:** `scripts/test_sim_lock.py` enthält die neun Fälle aus dem Testplan und wird von der CI ohne Änderung an `ci.yml` erfasst (`unittest discover -s scripts -p 'test_*.py'`); alle Skripttests in `scripts/` sind grün.
- **AC-19:** Kein Produktcode geändert, `.github/workflows/ci.yml` unverändert. Geräteliste: Kein Pfad der Geräteliste berührt (weder `Shared/Persistence/`, `LooseEnds*/`-Zielpfade, `project.yml`, Entitlements noch Info.plist). Keine sichtbare UI-Änderung, daher keine Entwurfsvorschau. Nach dem Merge ist `bash ~/.claude/scripts/loose-ends-sync-main.sh` gelaufen.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — reine Werkzeug- und Teständerung ohne Architekturwirkung auf das Produkt; keine bestehende Entscheidung wird gekippt.

## Changelog

- 2026-10-17: Spec erstellt (Teile A bis D, Belegläufe 1, 2, 3; #413 und #374 eingeschlossen).
