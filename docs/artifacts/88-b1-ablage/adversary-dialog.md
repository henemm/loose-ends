# Adversary Dialog — 88-b1-ablage
Spec: docs/specs/measurement/feat-88-b1-ablage.md
Datum: 2026-10-28 21:38

## Checkliste
- [x] **AC-1:** Ergebnis statt Ausnahme. Given ein Korpusname / When `Corpus.loadReport(fileName:)` läuft / Then liefert es entweder die Einträge oder genau einen benannten Grund, nie beides und nie still eine leere Liste. `Corpus.load` bleibt unverändert und wirft weiter.
- [x] **AC-2:** Datei fehlt. Given ein Name ohne Datei in Bundle, neben der Quelle, in `docs/reference/` oder in Documents / When `loadReport` läuft / Then ist der Grund „fehlt“ und der Text nennt den Korpusnamen („Korpus <name> fehlt …“).
- [x] **AC-3:** Datei kaputt. Given eine vorhandene Datei, die kein lesbares Korpusformat ist / When `loadReport` läuft / Then ist der Grund „unlesbar“, mit Korpusname und der Fehlerart, ohne Inhalt der Datei.
- [x] **AC-4:** Datei leer. Given eine vorhandene Datei, die gültig ist, aber null Einträge ergibt (leere Liste) / When `loadReport` läuft / Then ist der Grund „leer“ mit Korpusname.
- [x] **AC-5:** Datei in Ordnung. Given eine gültige Datei mit Einträgen / When `loadReport` läuft / Then liefert es dieselben Einträge wie `Corpus.load`, ohne Grund.
- [x] **AC-6:** Suchort `docs/reference/`. Given eine Datei `<name>.json` nur in `docs/reference/` des eigenen Arbeitsstands (neben `Measurement/`) / When `Corpus.url(fileName:)` sucht / Then findet es sie; Bundle bleibt vorrangig, danach `Measurement/`, `docs/reference/`, Documents. Die bisherigen Korpusse laden unverändert (`CorpusTests`).
- [x] **AC-7:** Läufer meldet laut. Given ein Korpus mit Grund / When `MeasurementRunner` startet / Then steht der Grund im Zustand `.paused(<Text>)` (die Labor-App zeigt ihn als Statuszeile), im Protokoll als Ereignis `korpus` und im `Logger`; das `try?` an dieser Stelle entfällt. `start` auf einem solchen Läufer misst nichts, schreibt aber ein Ereignis, statt still zurückzukehren.
- [x] **AC-8:** Lab-Ziel bindet die Datei optional. Given `project.yml` / When `generate` läuft mit und ohne `docs/reference/loose-ends-rawtexts.json` / Then gelingt es in beiden Fällen; nur mit Datei steht sie im Lab-Bündel, und nie in `LooseEnds`, `LooseEndsTests` oder `LooseEndsUITests`. In der CI (ohne Datei) bleibt „Generate leaves the tree clean“ grün.
- [x] **AC-9:** Worktree-Falle geschlossen. Given `sim.sh lab` aus einem Worktree, in dessen `docs/reference/` die Datei fehlt, im Hauptordner aber liegt / When es vor `generate` läuft / Then wird sie aus dem Hauptordner verlinkt (gitignoriert, nie überschrieben, nie bei vorhandener eigener Datei); fehlt sie auch dort, läuft der Bau weiter und der Läufer meldet AC-2 auf dem Gerät.
- [x] **AC-10:** Keine Sätze in Meldungen. Given Kunstdaten mit Marker-Wörtern / When `loadReport` einen Grund bildet / Then enthält der Text keines davon; nur Name, Art, Zahl.

## Dialog

### Runde 1
**Adversary:**
Eigener Lauf: `./scripts/sim.sh sim-unit CorpusLoadReportTests` -> Test Succeeded, 6 Tests der Suite einzeln grün
(Ausgabe: docs/artifacts/88-b1-ablage/adversary-run1-corpus.txt). Voll-Lauf-Beleg test-green-output.txt gelesen: Suite
„Korpus laden, laut scheitern“ dort grün; 3 von 6 Messstrecken übersprungen (nicht diese Änderung).
Screenshots geöffnet: lab-ohne-datei.png zeigt „Sätze 0 von 0“, Zustand „Korpus loose-ends-rawtexts fehlt: keine Datei im
Bündel, in Measurement/, docs/reference/ oder Documents.“, „Messen“ noch blau/antippbar; lab-mit-datei.png zeigt „Sätze 0 von 2“,
Zustand „Bereit.“. Läuferprotokoll gelesen: Ereignisse `korpus` und `start: abgelehnt: --measure; Korpus ohne Einträge`
vorhanden, danach `Korpus: 2 Sätze`.

- AC-1: AKZEPTIERT. Code reference: Measurement/Corpus.swift:187 — `loadReport` hat nur die Rückgaben `.problem` oder `.entries`, leere Liste wird `.empty`; `load` unverändert (der Diff berührt es nicht). Test: validFileMatchesLoad, missingFileNamesCorpus.
- AC-2: AKZEPTIERT. Corpus.swift:190 (fileNoSuchFile/fileReadNoSuchFile -> missing), Text enthält den Namen; Test missingFileNamesCorpus. Ein hängender Symlink: fileExists=false -> ebenfalls „fehlt“.
- AC-3: AKZEPTIERT. Corpus.swift:193 — Meldung nur aus Name, `type(of:)`, NSError.domain und -code, nie localizedDescription/userInfo; Test corruptFileIsUnreadable (Marker nicht im Text). Rechtefehler oder Verzeichnis statt Datei landen ebenfalls in „unlesbar“.
- AC-4: AKZEPTIERT. Test emptyListIsEmpty.
- AC-5: AKZEPTIERT. Test validFileMatchesLoad (Ids gleich, nicht leer).
- AC-6: AKZEPTIERT mit Vorbehalt F003. Corpus.swift:207-212: `bundled ?? [onDisk, reference, documents].first{exists}`; Reihenfolge im Code wie spezifiziert. Test urlFindsDocsReference.
- AC-7: AKZEPTIERT. Code reference: LooseEndsLab/MeasurementRunner.swift:65-76 — `try?` weg, bei Grund `.paused(message)`, `log("korpus")`, `logger.error`. Der Zustand wird danach nicht überschrieben: der `.finished`-Zweig braucht `!entries.isEmpty`; `stop()` (MeasurementRunner.swift:96) und `scene()` greifen nur bei `isActive`, `.paused` bleibt also stehen; `--measure` ruft `start`, das bei leerem Korpus nur ein Ereignis schreibt (MeasurementRunner.swift:85-89, Protokoll belegt). Offen nur: Knopf „Messen“ bleibt aktiv (F004, LOW).
- AC-8: NACHFRAGE (F001).
- AC-9: AKZEPTIERT mit Vorbehalt F002/F005. Code reference: scripts/sim.sh:883-895, 899. `set -eo pipefail` (sim.sh:44) ist unschädlich: `link_rawtexts_from_main || true` fängt jeden Rückgabewert, innerhalb der Funktion ist `rev-parse` mit `|| return 1` gesichert. ac9-trockenlauf.txt zeigt 4 Fälle (+ A2 zweiter Aufruf, D Hauptordner selbst).
- AC-10: AKZEPTIERT. Tests problemMessageNeverContainsSentences und corruptFileIsUnreadable; der Code kann Dateiinhalt strukturell nicht in die Meldung bringen (nur Typ-Name, Domain, Code).

Findings:
```
Finding:
  ID: F001
  Severity: MEDIUM
  Category: spec_violation
  Code reference: project.yml:296-305
  Description: Postbuild-Skript kopiert die Datei per `cp -L` in die Bündelwurzel des Lab-Ziels. Der Simulatorlauf mit Wegwerf-Datei belegt das nicht: im Simulator ist `#filePath` ein echter Mac-Pfad, `Corpus.url` findet die Datei in docs/reference/ des Arbeitsstands auch ohne Bündelkopie (Measurement/Corpus.swift:207-212). Die Lab-App steht nicht mehr in DerivedData, kein Bündel-Listing in den Artefakten.
  Spec requirement: AC-8 — nur mit Datei steht sie im Lab-Bündel, nie in LooseEnds, LooseEndsTests, LooseEndsUITests; ohne Datei gelingt der Bau.
  Conflict: Das Gerät sieht nur das Bündel (kein Mac-Pfad). Ob die Kopie wirklich im .app liegt und in den drei anderen Bündeln nicht, ist unbelegt; ebenso das Entfernen einer alten Kopie (rm -f-Zweig).
  Remediation: Lab-Bau (Simulator) ohne Datei, mit Datei, wieder ohne Datei; jedes Mal `ls` von LooseEndsLab.app (und LooseEnds.app, LooseEndsTests.xctest, UITests-Runner) ins Artefakt.

Finding:
  ID: F002
  Severity: MEDIUM
  Category: edge_case
  Code reference: scripts/sim.sh:278 und scripts/sim.sh:884
  Description: `ensure_project` erzeugt nur, wenn LooseEnds.xcodeproj fehlt. Der Kommentar bei link_rawtexts_from_main behauptet, ein neues `generate` sei nicht nötig. Das Skript steht aber erst nach `generate` im Projekt; ein Arbeitsstand mit schon erzeugtem, älterem Projekt baut die Lab-App ohne Skript.
  Spec requirement: AC-9 — Datei wird verlinkt und gelangt auf das Gerät; fehlt sie, meldet der Läufer AC-2.
  Conflict: Datei ist verlinkt, aber nicht im Bündel -> Läufer meldet „fehlt“, obwohl sie da ist (irreführende, aber laute Meldung). Der Kommentar ist falsch.
  Remediation: cmd_lab ruft `cmd_generate` (wie sim.sh:649) oder vergleicht den project.yml-Zeitstempel; Kommentar korrigieren.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsTests/CorpusTests.swift:327-335
  Description: Kein Test für die Reihenfolge Measurement/ vor docs/reference/ vor Documents, nur „docs/reference wird gefunden“. Der Test legt die Datei im echten Ordner docs/reference/ ab und räumt per defer auf; bei Abbruch bleibt b1a-ref-*.json liegen.
  Spec requirement: AC-6 — Bundle bleibt vorrangig, danach Measurement/, docs/reference/, Documents.
  Conflict: Reihenfolge nur durch Code-Lesen belegt.
  Remediation: Test mit gleichem Namen in docs/reference und Documents erwartet docs/reference.

Finding:
  ID: F004
  Severity: LOW
  Category: anti_pattern
  Code reference: LooseEndsLab/MeasurementRunner.swift:85-89
  Description: Bei Korpusproblem bleibt „Messen“ in der Labor-App antippbar (Screenshot lab-ohne-datei.png), das Tippen schreibt nur ein Protokollereignis, die Statuszeile bleibt.
  Spec requirement: AC-7 — start misst nichts, schreibt Ereignis.
  Conflict: Kein Verstoß; LabApp.swift ist ausdrücklich außerhalb des Umfangs. Nur Hinweis.
  Remediation: keine nötig, ggf. später Knopf sperren.

Finding:
  ID: F005
  Severity: LOW
  Category: edge_case
  Code reference: scripts/sim.sh:889
  Description: `--path-format=absolute` bei rev-parse verlangt eine neuere Version der Versionsverwaltung (2.31+); bei älterer kommt still `return 1` ohne Hinweis, es wird nicht verlinkt.
  Spec requirement: AC-9
  Conflict: Folge ist die laute Läufer-Meldung „fehlt“; kein Datenverlust.
  Remediation: `info`-Hinweis im Fehlerfall.
```
**Implementierer:**

### Runde 2
**Adversary:**
Belege gelesen, Screenshot lab-nur-buendel.png geöffnet: „Loose Ends Labor“, Sätze „0 von 2“, Zustand „Bereit.“, „Messen“ aktiv, keine „fehlt“-Zeile.
Kein eigener Testlauf nötig (Rechner ausgelastet): test-green-output.txt zeigt Test Succeeded, 1071 Haken, 0 Fehlschläge, beide neuen Tests (Zeilen 226-227).

- F001: AKZEPTIERT. bundle-belege.txt: Bau 1 ohne Datei 12 Wurzeleinträge, Bau 2 mit Datei 13 und `loose-ends-rawtexts.json` (270 Byte), Bau 3 ohne Datei wieder 12 (rm -f-Zweig, Skriptphase lief). LooseEnds.app, LooseEndsTests.xctest und UITests-Runner: 0 Treffer, Gegenprobe zeigt, dass die Suche in Bündel sieht. Kritisch geprüft: Der Lauf „Datei nur im Bündel“ löschte vorher docs/reference/ und prüfte Measurement/ (beide fehlen), also nicht über `#filePath` gefunden; der Screenshot belegt den Bündelweg. Code reference: project.yml:295-305 (Skript, `ENABLE_USER_SCRIPT_SANDBOXING: NO` in :321).
- F002: AKZEPTIERT. Code reference: scripts/sim.sh:899-909 — `cmd_generate || return 1` steht nach `link_rawtexts_from_main || true` und vor `signed_build`; unter `set -eo pipefail` fängt `|| true` das `return 1`, `cmd_generate` ist ein eigener Befehl mit eigenem `|| return 1`. Kommentar in sim.sh:884-886 jetzt richtig. cmd_lab selbst nicht ausgeführt (Gerät).
- F003: AKZEPTIERT. Code reference: LooseEndsTests/CorpusTests.swift:337-359 — `defer` mit Löschung beider Dateien steht vor den Schreibvorgängen, Namen mit UUID (kein Flackern bei Parallellauf; die einzige Verzeichnisaufzählung in Tests, DateTitleReportTests.swift:14, liest Measurement/results, nicht diese Ordner). `urlPrefersBundle` prüft Präfix des Test-Bündels. Nach dem Lauf liegt nichts in docs/reference/ oder Measurement/ (ls geprüft).
- F004: unverändert LOW, bewusst nicht behoben (LabApp außerhalb des Umfangs).
- F005: AKZEPTIERT. Code reference: scripts/sim.sh:891-892 — Hinweis „Hauptordner nicht ermittelbar“; ac9-trockenlauf.txt Fall E belegt ihn, A/A2/B/C/D unverändert.
- Läufer unverändert nach Runde 1: Code reference: LooseEndsLab/MeasurementRunner.swift:65-76 (corpusProblem -> `.paused`, `log("korpus")`, `logger.error`) und Measurement/Corpus.swift:187-212 gleich wie in Runde 1.
- AC-7, AC-8, AC-9 nun bewiesen und abgehakt; alle 10 ACs bewiesen.

Geprüfte Stellen (je Zeile, damit der Stempel sie hasht):
Code reference: Measurement/Corpus.swift:187-212
Code reference: LooseEndsLab/MeasurementRunner.swift:65-76
Code reference: project.yml:295-321
Code reference: scripts/sim.sh:883-909
Code reference: LooseEndsTests/CorpusTests.swift:337-359
**Implementierer:**

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Die Implementierung hat die Prüfung überstanden.
Tests: 1096 bestanden, 0 fehlgeschlagen, 10 übersprungen (je begründet)
Edge Cases: geprüft, keine gebrochen (offen nur LOW: F004, bewusst)
Regressions: keine gefunden
Checklist: 10/10 Punkte bewiesen

## Geprüfte Dateien

- sha256:8999c90096fd1f16466b0e1f060d8dec38b115fdf24bd3836547942b59ac7561  LooseEndsLab/MeasurementRunner.swift
- sha256:59467ebdcfa373064280db57484330e8cade50c887f99b4d7e7640727a6dbf86  LooseEndsTests/CorpusTests.swift
- sha256:7f661ba0623c0c787bbdb1bf1a0e0346e3fd6e224a5e86b34956369621653dbb  Measurement/Corpus.swift
- sha256:bf3bd1c11d3e05c0ec9b429aa579d8da00b42bdcf80f9c6b955270f460cd464d  project.yml
- sha256:492bf26ea1eea0f94a1b02ea19dcff18cc3213f6b29bfb156826489f61b6f2c4  scripts/sim.sh

## Prüfbasis

- base: 793fcf6da25bb6b29e62adba4d9b2935ef1114a2
- blob:99d100ef271a5ef7d8de46e87b5a69b79e3d6d06  LooseEndsLab/MeasurementRunner.swift
- blob:c9cfbd0a6944589fbf9f2fd4a76923fc682ee25d  LooseEndsTests/CorpusTests.swift
- blob:fd12730f2d80ab31dda4c7bf7db1a245ae3b30aa  Measurement/Corpus.swift
- blob:690811c46fcd45ce812d6970af5a98475e3b223c  project.yml
- blob:b6ac0113ed8213b7fe1d5ba0254a2bb53f89cd95  scripts/sim.sh
