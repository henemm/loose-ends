# Adversary Dialog — fix-670-testsprache
Spec: docs/specs/feat-670-testsprache.md
Datum: 2026-10-24 16:20

## Checkliste
- [x] **AC-1:** Ohne `LOOSEENDS_LANG` ist die Argumentliste von `run_xcodebuild test …` byte-gleich zu vorher. Belegt durch `test_without_variable_arguments_are_unchanged` und die unveränderten Tests #298.
- [x] **AC-2:** `LOOSEENDS_LANG=en` ergibt bei `test` genau `-testLanguage en -testRegion US`. Belegt durch `test_en_sets_language_and_region`; `de` durch `test_de_sets_de_region`.
- [x] **AC-3:** Ein gültiger Code außerhalb der Region-Tabelle ergibt nur `-testLanguage`, ohne `-testRegion`. Belegt durch `test_unknown_valid_code_sets_language_only`.
- [x] **AC-4:** Ein ungültiger Wert (leer bei gesetzter Variable, nicht `^[a-z]{2}$`) bricht mit Meldung auf stderr und Exit ≠ 0 ab, bevor `xcodebuild` läuft. Belegt durch `test_invalid_values_abort_loudly`.
- [x] **AC-5:** Andere Aktionen als `test` bleiben unberührt, auch bei gesetzter oder leerer Variable. Belegt durch `test_build_action_ignores_variable`.
- [x] **AC-6:** Die Wirkung gilt über `run_xcodebuild` für `sim-unit`, `test`, `test-proof` und `watch-test-proof`, ohne dass deren Funktionen geändert werden. Belegt durch Diff (nur `run_xcodebuild` in `sim.sh` geändert) und AC-7 für `sim-unit`.
- [x] **AC-7:** Abnahme am echten Lauf (Stufe 2): `LOOSEENDS_LANG=en ./scripts/sim.sh sim-unit KnaeuelTests` ist grün, und ein sprachabhängiger Nachweis zeigt, dass wirklich Englisch gilt, ohne Variable Deutsch. (Abweichung print -> Dateischreib-Test bewertet, siehe Runde 2.)
- [x] **AC-8:** `CLAUDE.md` enthält die Befehlszeile aus „Implementation Details“ im Abschnitt „Build“. Belegt durch Diff.

## Dialog

### Runde 1
**Adversary:** Ich glaube den Tests nicht. Lauf selbst: `python3 -m unittest scripts.test_sim_run_xcodebuild -v` -> 17 Tests, OK (6 neue + 11 alte #298/#516). Der Test für AC-1 prüft nur `args[:5]`; ich habe die volle Liste von Hand gegen eine Attrappe geprüft. Grenzfälle gegen die aus sim.sh gezogene Funktion, je mit `set -euo pipefail` und `set -eo pipefail`, mit /bin/bash 3.2.57 (die `bash` im PATH ist ebenfalls 3.2.57, eine neuere Bash war nicht verfügbar):
- `en\n` (Zeilenumbruch am Ende, `$`-Anker): abgebrochen, Attrappe nicht aufgerufen. `en ` abgebrochen. `éé` abgebrochen. `EN`, `en-US`, `` (gesetzt, leer), `e\nn`, `en\nxx`: alle abgebrochen, stderr nennt Variable und Wert, keine xcodebuild-Aufruf.
- `en`: `test -project P -collect-test-diagnostics never -testLanguage en -testRegion US -derivedDataPath … CODE_SIGNING_ALLOWED=NO`, rc=0. Variable ungesetzt: gleiche Liste ohne die beiden Schalter (byte-gleich zum Vorzustand, `-collect-test-diagnostics never` bleibt vor dem Wächter).
- `build`, `build-for-testing`, `test-without-building` mit `en`: Argumente unverändert, rc=0, Variable wird nicht gelesen (nur `test` gilt, wie die Spec sagt). Ein `test` an Position 2 (`-project P test`) bekommt nichts, ebenfalls spec-konform.
Aufrufer: `set -eo pipefail` (sim.sh:43) und `trap release_testlock EXIT` (sim.sh:238). `cmd_sim_unit`/`cmd_test`/`cmd_unit` rufen `run_xcodebuild test …` ohne `||`: `return 1` beendet das Skript, EXIT-Trap gibt die Sperre frei, kein Erfolg. `cmd_test_proof`/`cmd_real_model` fangen mit `|| rc=$?`: rc=1, Sperre wird in test-proof explizit freigegeben, Beleg-Prüfung bekommt rc=1 und meldet Fehlschlag. Kein Fehler, aber zwei Unschönheiten.
**Implementierer:** (Nachweis des Prüfers) Alle genannten Läufe sind reproduzierbar mit der Attrappe unter dem Scratchpad; Ergebnis: kein Fehlverhalten. Funde (nicht blockierend):
- F001 LOW edge_case: Die Validierung greift erst in `run_xcodebuild`, also nach `acquire_testlock`, `ensure_project`, `cmd_boot` (Simulator wird gestartet und das Projekt erzeugt, bevor ein Tippfehler in der Sprache auffällt). Code reference: scripts/sim.sh:297. Spec (Punkt 3: „bevor xcodebuild startet“) ist erfüllt; frühere Prüfung wäre nur komfortabler.
- F002 LOW edge_case: In `cmd_test_proof` meldet der Abbruch zusätzlich „UI-Test fehlgeschlagen (xcodebuild 1)“, obwohl xcodebuild nie lief; `BUILD_LOG` kann dabei noch das alte Log sein (wird erst nach dem Abbruchpunkt geleert). Der Beleg wird wegen rc=1 trotzdem nicht grün. Code reference: scripts/sim.sh:299.

### Runde 2
**Adversary:** AC-7 und AC-6/AC-8 gezielt. `git diff --stat`: nur CLAUDE.md (+1) und scripts/sim.sh (+15); der einzige Hunk in sim.sh liegt in Zeilen 292-308, also innerhalb von `run_xcodebuild` (Z. 288-). `cmd_sim_unit`, `cmd_test`, `cmd_test_proof`, `cmd_watch_test_proof` unverändert, sie rufen alle `run_xcodebuild test` (Z. 584, 594, 633). `git diff HEAD -- LooseEndsTests project.yml` leer, `ls LooseEndsTests | grep -i probe` leer, `grep LocaleProbe -r LooseEndsTests project.yml` leer: die Probe ist entfernt, nichts davon im Diff. CLAUDE.md Z. 64 enthält die Zeile wörtlich aus der Spec, direkt hinter `watch-test-proof`, im Codeblock unter „Build“.
AC-7-Belege gelesen: `ac7-locale-mit-variable.txt` = `LOCALEPROBE preferred=en current=en_US`; `ac7-locale-ohne-variable.txt` = `LOCALEPROBE preferred=de-DE current=de_DE`. Die Logs `ac7-mit-variable.txt` / `ac7-ohne-variable.txt` zeigen je einen grünen Lauf von `LocaleProbe670Tests` (Swift Testing, `reportsLocale()` bestanden), `ac7-knaeuel-en.txt` einen grünen KnaeuelTests-Lauf („Test Succeeded“, Suite „Das Knäuel (#643)“ passed). Die Spec-Abweichung `print` -> Dateischreib-Test: Swift-Testing-`print` erscheint, wie der Implementierer sagt, nicht im xcbeautify-/xcodebuild-Log; die Spec fordert den Nachweis „Locale in den Lauf schreiben“ und das Ziel (mit Variable en, ohne de), nicht das Mittel. Die Abweichung ist daher zulässig und sogar stärker, weil der Wert aus dem Testprozess selbst stammt. Restzweifel: Die beiden Locale-Dateien sind Kopien; der Prüfer kann ihre Frische nicht aus den Logs ableiten (Zeitstempel 15:59, Läufe 15:58:53 mit, 15:59:29 ohne). Da die Inhalte verschieden sind (en gegen de), kann kein veralteter Dateistand beide erklären. Der Simulator wurde vom Prüfer nicht gestartet.
**Implementierer:** (Nachweis des Prüfers) Keine weiteren Brüche gefunden. Die offene Frage der Spec („wirkt -testLanguage unter Xcode 27 auf Unit-Tests im iOS-Simulator?“) ist durch die Belege positiv beantwortet: der Rückfall `-AppleLanguages` ist nicht nötig. Einschränkung: Mac-Läufe `cmd_real_model_latency` nutzen `test-without-building`, bekommen also bewusst keine Sprache (Spec: nur `test`).

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

Code reference: scripts/sim.sh:297
Code reference: scripts/sim.sh:307
Code reference: CLAUDE.md:64
Code reference: scripts/test_sim_run_xcodebuild.py:71

## Verdict

VERDICT: VERIFIED — 17 Tests grün (0 fehlgeschlagen, 0 übersprungen), AC-1 bis AC-8 mit eigenem Beweis; zwei LOW-Funde (F001 späte Validierung, F002 irreführende Zusatzmeldung in test-proof), nicht blockierend. Die Abweichung print -> Dateischreib-Test ist zulässig.

## Geprüfte Dateien

- sha256:f98a48a3f64b2aa75e4d630cdd7367377216c6a6249096dc6cd06961a7aff178  CLAUDE.md
- sha256:45ad493d4d68c9fe842a5b717f73a1ad9deb185db41c3ba220e76dcad12bb5da  scripts/sim.sh
- sha256:d4557a350cd5ffbd920a6623f0f377485d75996ae5105a6a492342b9ef4844f2  scripts/test_sim_run_xcodebuild.py

## Prüfbasis

- base: 4d3649538149471671f607427c2746e762ac7d22
- blob:9cbf793f89fd25f49447590043cc28e6c3242529  CLAUDE.md
- blob:910be8882690c2b74abea78f4cb0ec9c698bcf8c  scripts/sim.sh
- blob:c61516ec457d8067a8bb8e341e09ec9913705d44  scripts/test_sim_run_xcodebuild.py
