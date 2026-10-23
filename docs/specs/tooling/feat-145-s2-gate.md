---
entity_id: feat-145-s2-gate
type: feature
created: 2026-10-22
updated: 2026-10-22
status: draft
workflow: feat-145-s2-gate
---

# Spec: #145 Schnitt 2 — Gate vor `phase8_complete` erzwingt den Simulator-Beleg

## Approval

- [ ] Approved

## Purpose

### Problem

Schnitt 1 (PR #167) erzeugt mit `scripts/sim.sh test-proof <Klasse>` einen maschinellen Simulator-Beleg
(`docs/artifacts/<wf>/simulator-run.txt` samt `simulator-run/{summary.json,*.png,run.xcresult}`). Nichts zwingt
aber dazu, ihn zu erzeugen: Das Plugin `agent-os-openspec` (3.41.0) kennt weder `simulator-run` noch `xcresult`.
Ein Ticket mit sichtbarer Änderung kann `phase8_complete` erreichen, ohne dass die App je im Simulator benutzt
wurde (Lehre #136, CLAUDE.md „Die App wird benutzt, nicht nur gebaut"). Ein Gate, das man selbst öffnen kann,
ist kein Gate; also muss das Werkzeug den Beleg erzwingen, nicht die Disziplin.

### Ziel

Kein `phase8_complete` (und damit kein `complete`/`finish`) ohne gültigen, maschinell erzeugten Beleg, der zum
aktuellen Stand der Produktionsdateien passt und dessen Ergebnis aus dem Original-`run.xcresult` neu abgeleitet
wurde. Fälschen soll aufwendiger sein als der ehrliche Lauf und auffallen (Tech-Lead-Entscheidung 2026-10-01).
Regelweg, kein Modell: reine Datei-, Prüfsummen- und Zählervergleiche.

### Zwei Repos, zwei Workflows (klar getrennt)

- **Plugin-Repo `henemm/agent-os-openspec`:** Den Gate-Code (Schnitt 2a) und die Schreibsperre (Schnitt 2b) baut ein
  eigener Workflow dort, Ticket `henemm/agent-os-openspec#447` (Teil von Epic `#430`). Die Scope- und Edit-Gates
  messen das Repo, in dem der Workflow lebt; ein Loose-Ends-Workflow sähe den Plugin-Code nicht.
- **Dieser Workflow (Loose Ends):** trägt die Spezifikation des Gate-Verhaltens (die ACs unten gelten als
  Abnahmekriterien für #447), das **Einschalten** in `openspec.yaml` und den **Pilot** am nächsten UI-Ticket.
- **Außerhalb dieser Spec:** Schnitt 3 (Doku in `docs/reference/abnahme-und-arbeitsweise.md` und `CLAUDE.md`;
  `docs/project/04-stand.md` ist aufgelöst und wird nicht neu angelegt).

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine — reines Prozess-Werkzeug, kein Produkt- oder Architekturthema der App; die Grundlage ist die
Tech-Lead-Entscheidung vom 2026-10-01 in #145 („Gate leitet lokal aus `run.xcresult` ab", Signatur verworfen,
„Gate fährt selbst" als späteres Zielbild), kein Eintrag in `docs/project/00-entscheidungen.md` nötig.

## Source

- **Plugin (nur gelesen, gebaut in #447):** `core/hooks/workflow.py` (Phase-8-Zweig in `_validate_transition`,
  `cmd_add_artifact`, `cmd_set_field` mit `_SET_FIELD_PROTECTED`, `cmd_complete`), `core/hooks/adversary_dialog.py`
  (`_EXAMINED_FILES_LINE_RE`, `phase8_code_files`, `_outside_roots`, `check_dialog_evidence` als Vorbild),
  `core/hooks/hook_utils.py` (`is_gated_code_path`), `core/hooks/config_loader.py`, `config.yaml`,
  `core/hooks/edit_gate.py`, `core/hooks/bash_gate.py`.
- **Loose Ends:** `openspec.yaml`; Erzeuger `scripts/sim_proof.py` und `scripts/sim.sh` (`cmd_test_proof`)
  bleiben unverändert (siehe Drift-AC).
- **Recherche zum Format:** `xcrun xcresulttool get test-results summary --path … --compact` (Xcode 27.1 lokal,
  Schema 0.4.0, versioniert; Apple veröffentlicht das Format nicht separat, Schema per `--schema`). Quellen:
  developer.apple.com/forums/thread/763050 und /thread/763888. Folge: **semantisch** vergleichen (Ergebnis,
  Zähler), nicht byteweise, damit ein Xcode-Update zwischen Lauf und Abschluss keinen ehrlichen Beleg bricht.

## Dependencies

| Baustein | Art | Zweck |
|---|---|---|
| `xcrun xcresulttool` (macOS mit Xcode) | Upstream | Neuableitung von Ergebnis und Zählern aus `run.xcresult`, mit Timeout |
| `git` (lesend) | Upstream | Änderungsmenge seit Basis (`phase8_code_files`) |
| Schnitt 1 (`sim.sh test-proof`, `sim_proof.py`) | Upstream | erzeugt Beleg und Bündel |
| Plugin-Release mit 2a | Voraussetzung | muss erscheinen und installiert sein, **bevor** `openspec.yaml` das Gate einschaltet; 2b danach |
| Jedes Projekt mit dem Plugin | Downstream | unverändert, solange es keinen Abschnitt `evidence_checks` hat |

## Scope

### In

- Schnitt 2a: Gate vor `phase8_complete` (neue Datei `evidence_gate.py`, eine Aufrufstelle im Phase-8-Zweig,
  Konfigurationsabschnitt `evidence_checks`, Opt-in je Projekt).
- Schnitt 2b: Schreibsperre auf den Beleg (Write/Edit und Bash-Umleitungen).
- Loose Ends: `evidence_checks` und `exempt_paths` in `openspec.yaml`; Pilot an einem echten UI-Ticket.

### Out

- Schnitt 3 (Doku). Commit-Gate (Beleg sperrt „fertig", nicht Zwischenstände). Neuer Artefakttyp
  `simulator_run`. Signatur des Belegs. Dass das Gate selbst den Simulatorlauf fährt (Zielbild später).
  Änderungen an `sim_proof.py` (Menge ist schon Obermenge).

### Betroffene Dateien mit Schätzung

**Plugin-Repo `henemm/agent-os-openspec` (Ticket #447):**

| Datei | Änderung | Schnitt |
|---|---|---|
| `core/hooks/evidence_gate.py` | CREATE: `check_evidence(target_phase, wf) -> str\|None`, fail-closed, Verifier-Registry mit erstem Mitglied `xcresult_proof` | 2a |
| `core/hooks/workflow.py` | MODIFY: eine Aufrufstelle im Phase-8-Zweig nach dem Dialog-Check (gilt damit auch für `complete` und `finish`) | 2a |
| `core/hooks/config_loader.py`, `config.yaml` | MODIFY: Abschnitt `evidence_checks` (Default leer), Schlüssel in `PLUGIN_CONFIG_KEYS` | 2a |
| `tests/test_evidence_gate_447.py` | CREATE (gebaut, PR #449; enthält auch 2b) | 2a, 2b |
| `core/hooks/edit_gate.py`, `core/hooks/bash_gate.py` | MODIFY: Sperre auf `docs/artifacts/*/simulator-run.txt` und `simulator-run/` | 2b |

Schätzung 2a: 4 Produktionsdateien, ca. +170 LoC Prod, ca. +250 LoC Test. Schätzung 2b: 2 bis 3 Dateien, ca. +40
LoC Prod, ca. +120 LoC Test. Beide bleiben je Schnitt in den Scoping-Limits; wird eine Grenze beim Bau überschritten,
wird vor dem Weiterbauen gestoppt.

**Loose Ends (dieser Workflow):**

| Datei | Änderung | Schätzung |
|---|---|---|
| `openspec.yaml` | MODIFY: Abschnitt `evidence_checks` mit `phase8_complete` und `exempt_paths` | +6 Zeilen |
| `scripts/test_evidence_config.py` | CREATE (optional, falls keine bestehende Prüfung passt): liest `openspec.yaml`, prüft Form und Drift-Bedingung | ca. +60 LoC |

### Konfiguration in Loose Ends (verbindliche Form)

```yaml
evidence_checks:
  phase8_complete:
    - verifier: xcresult_proof
      file: simulator-run.txt
  exempt_paths: ["LooseEnds/Mac/*"]
```

Schlüsselnamen und Ebene folgen dem gebauten Plugin (#447, PR #449): `verifier`/`file` je Eintrag, `exempt_paths`
neben `phase8_complete` als `fnmatch`-Muster auf repo-relative Pfade (`*` umfasst auch `/`). Jede andere Form weist
das Plugin als kaputte Config ab und sperrt damit jeden Abschluss, auch gegen ein `override`.

`LooseEnds/Mac/` ist Mac-only und hat keinen Simulator-UI-Test (der Mac-Nachweis läuft über die Mac-Galerie in
der CI). Weitere Ausnahmepfade nur mit begründeter Änderung dieser Datei.

## Was das Gate prüft (Schnitt 2a)

1. Ist für `phase8_complete` ein `evidence_checks`-Eintrag konfiguriert? Sonst nichts tun.
2. Gate-Menge = `phase8_code_files(wf)` abzüglich `exempt_paths`. Leer: kein Beleg nötig.
3. `docs/artifacts/<wf>/simulator-run.txt` existiert, liegt im Projekt (`_outside_roots`), Kopf lesbar.
4. Jede Datei der Gate-Menge steht im Block `## Geprüfte Dateien` mit dem Hash des Arbeitsbaums
   (Obermenge im Beleg erlaubt). **Keine Bindung an `head:`**: Rebase oder Amend ohne Codeänderung entwertet
   den Beleg nicht.
5. `summary.json` passt zur Prüfsumme der Zeile `summary:`; `run.xcresult` liegt daneben.
6. Neuableitung per `xcresulttool` (mit Timeout): `result`, `totalTestCount`, `passedTests`, `failedTests`,
   `skippedTests` stimmen mit `summary.json` und den Zeilen `ergebnis:`/`tests:` überein; verlangt `Passed` und
   mindestens ein bestandener Test.

Das Gate liest den festen Pfad. Es gibt keinen neuen Artefakttyp: ein Registereintrag wäre nur ein weiteres
fälschbares Feld.

## Acceptance Criteria

AC-1 bis AC-22 gelten für das Plugin (#447, gebaut in PR #449, Tests in `tests/test_evidence_gate_447.py`); verlangt
ist der Sinn der Meldung, nicht ein Wortlaut. AC-23 und AC-24 gelten für Loose Ends. „Gate" meint die Prüfung beim Übergang nach `phase8_complete`, auch über `complete` und `finish`.
Der Nachweis, dass es greift, ist jeweils ein bewusster Fehlversuch.

- **AC-1:** Kein Beleg, bewusster Fehlversuch. Given `evidence_checks` ist für `phase8_complete` gesetzt, eine
  Gate-Datei (z. B. `LooseEnds/Views/Foo.swift`) ist seit der Basis geändert und es existiert kein
  `simulator-run.txt` / When der Übergang nach `phase8_complete` versucht wird / Then wird er abgelehnt, und die
  Meldung nennt den fehlenden Beleg und den Befehl `scripts/sim.sh test-proof`.
- **AC-2:** Veralteter Hash. Given ein gültiger Beleg, danach wird eine Gate-Datei inhaltlich verändert / When der
  Übergang versucht wird / Then Ablehnung, die Meldung nennt den Pfad dieser Datei und dass sie nach dem Lauf geändert wurde.
- **AC-3:** Datei fehlt im Beleg. Given ein gültiger Beleg, danach kommt eine weitere Gate-Datei (geändert oder
  neu) hinzu, die im Block `## Geprüfte Dateien` fehlt / When der Übergang versucht wird / Then Ablehnung mit dem
  Pfad der nicht gebundenen Datei.
- **AC-4:** Ergebnis nicht bestanden. Given ein Beleg mit `ergebnis: Failed` oder `Unbekannt` / When der Übergang
  versucht wird / Then Ablehnung mit dem Ergebniswert in der Meldung.
- **AC-5:** Null Tests. Given ein Beleg mit `ergebnis: Passed`, aber `tests: 0 gesamt` (oder 0 bestanden) /
  When der Übergang versucht wird / Then Ablehnung mit dem Hinweis „kein bestandener Test".
- **AC-6:** `summary.json` manipuliert. Given ein Beleg, dessen `summary.json` nach dem Lauf verändert wurde, sodass
  die Prüfsumme der Zeile `summary:` nicht mehr stimmt / When der Übergang versucht wird / Then Ablehnung, die Meldung
  nennt `summary.json` und die Prüfsumme.
- **AC-7:** Bündel fehlt. Given ein sonst gültiger Beleg, dessen `simulator-run/run.xcresult` fehlt / When der
  Übergang versucht wird / Then Ablehnung mit „run.xcresult fehlt".
- **AC-8:** Neuableitung weicht ab. Given ein Beleg und eine `summary.json`, die `Passed` und 3 bestandene Tests
  angeben, während die Neuableitung aus `run.xcresult` ein anderes `result` oder andere Zähler liefert / When der
  Übergang versucht wird / Then Ablehnung, die beide Werte (Beleg, Neuableitung) nennt.
- **AC-9:** Format-Versionsunabhängigkeit. Given ein Beleg, dessen `summary.json` und Neuableitung in
  `result` und den fünf Zählern gleich sind, sich aber in anderen Feldern oder der Feldreihenfolge unterscheiden /
  When der Übergang versucht wird / Then wird er nicht wegen dieses Unterschieds abgelehnt (semantischer, nicht
  byteweiser Vergleich).
- **AC-10:** `xcresulttool` nicht nutzbar, fail-closed. Given `xcresulttool` fehlt (z. B. Linux) oder
  überschreitet das Zeitlimit / When der Übergang versucht wird / Then Ablehnung mit einer Meldung, die
  `xcresulttool` und „nicht verfügbar" bzw. „Zeitlimit" nennt; es wird nie stillschweigend durchgelassen, und das Gate wirft
  keine Ausnahme.
- **AC-11:** Gültiger Beleg wird akzeptiert. Given ein von `scripts/sim.sh test-proof` erzeugter Beleg, dessen
  Hashes zum Arbeitsbaum passen, mit `ergebnis: Passed` und passender Neuableitung / When der Übergang versucht
  wird / Then lässt das Gate ihn durch (die Adversary- und Dialog-Prüfungen gelten weiter unverändert).
- **AC-12:** Keine Bindung an `head:`. Given ein gültiger Beleg und ein Rebase (oder Amend) ohne Änderung des
  Dateiinhalts, sodass `head:` im Beleg nicht mehr dem aktuellen HEAD entspricht / When der Übergang versucht wird /
  Then wird er nicht wegen `head:` abgelehnt.
- **AC-13:** Keine Gate-Datei geändert. Given die seit der Basis geänderten Dateien sind nur Doku, Skripte oder
  Tests (`docs/`, `scripts/`, `*.md`) / When der Übergang versucht wird / Then verlangt das Gate keinen Beleg.
- **AC-14:** Nur Ausnahmepfade geändert. Given die einzige geänderte Gate-Datei liegt unter einem
  `exempt_paths`-Muster (z. B. `LooseEnds/Mac/MenuBarCapture.swift` unter `LooseEnds/Mac/*`) / When der Übergang versucht wird /
  Then verlangt das Gate keinen Beleg. Given zusätzlich eine Datei außerhalb der Ausnahmepfade geändert ist /
  Then verlangt es ihn weiter (und prüft nur diese Datei gegen den Beleg).
- **AC-15:** Projekt ohne Konfiguration unverändert. Given ein Projekt ohne Abschnitt `evidence_checks` (oder mit
  leerem) / When es nach `phase8_complete` geht / Then ist das Verhalten identisch zu Plugin 3.41.0, nachgewiesen
  durch einen Test mit leerer Konfiguration, der kein Dateisystem außerhalb des Workflows liest.
- **AC-16:** Gilt für `complete` und `finish`. Given dasselbe Gate-Szenario wie AC-1 / When statt des direkten
  Übergangs `workflow.py complete` und `workflow.py finish` aufgerufen werden, auch bei bereits gesetzter Phase 8 /
  Then lehnen beide gleichermaßen ab.
- **AC-17:** Kein neuer Artefakttyp, nichts per Hand zu öffnen. Given das Gate / When `add-artifact simulator_run`
  aufgerufen wird / Then bleibt der Typ unbekannt (Ablehnung wie heute); When `set-field` ein Feld setzt, das den
  Beleg ersetzen könnte, oder `add-artifact` einen anderen Pfad meldet / Then ändert das nichts am Gate-Ergebnis:
  gelesen wird ausschließlich der feste Pfad `docs/artifacts/<wf>/simulator-run.txt`.
- **AC-18:** Beleg außerhalb des Projekts. Given der feste Pfad ist ein Symlink, der aus dem Projekt zeigt /
  When der Übergang versucht wird / Then Ablehnung (Prüfung „liegt im Projekt“ vor dem Lesen), der Inhalt wird nicht gelesen.
- **AC-19:** Schreibsperre (Schnitt 2b). Given ein aktiver Workflow / When ein Write- oder Edit-Aufruf auf
  `docs/artifacts/<wf>/simulator-run.txt` oder eine Datei in `docs/artifacts/<wf>/simulator-run/` zielt, oder ein
  Bash-Befehl, dessen Text eine dieser Dateien mit `>`, `>>`, `tee`, `cp`, `mv`, `sed -i` oder `rm` beschreibt /
  Then wird der Aufruf blockiert, mit Meldung, dass der Beleg nur von `scripts/sim.sh test-proof` erzeugt wird.
- **AC-20:** Erzeuger bleibt erlaubt. Given dieselbe Sperre / When `scripts/sim.sh test-proof <Klasse>` per Bash
  aufgerufen wird / Then wird der Aufruf nicht blockiert (erkannt am Befehl, nicht am Pfad allein), und der Beleg
  entsteht. Lesende Zugriffe (`cat`, Read) auf Beleg und Bündel bleiben erlaubt.
- **AC-21:** Drift zwischen Erzeuger und Gate. Given die Dateimenge, die `scripts/sim_proof.py` in den Beleg
  schreibt, und die Gate-Menge des Plugins mit der Loose-Ends-Konfiguration (`is_gated_code_path` des installierten
  Plugins, abzüglich `evidence_checks.exempt_paths` als `fnmatch`-Muster wie im Plugin) / When ein Test beide für ein
  Musterset von Pfaden (`.swift` unter `LooseEnds/`, `Shared/`, `LooseEndsTests/`, `LooseEndsUITests/`,
  `Measurement/`, sowie `docs/`, `scripts/`, `*.md`, `*.json`) berechnet / Then ist die Erzeuger-Menge eine
  Obermenge der Gate-Menge. Der Test schlägt fehl, wenn das Plugin eine Endung oder einen Pfad zählt, den
  `sim_proof.py` nicht zählt.
- **AC-22:** Override nur durch Henning. Given das Gate lehnt ab / When der Agent versucht, es zu umgehen (kein
  Beleg registrieren, `set-field`, Verzicht-Artefakt) / Then bleibt die Ablehnung; ausgenommen wird nur über den
  bestehenden Mechanismus mit Hennings **getipptem** `override` (Einstunden-Fenster, nur das Wort „override"
  zählt). Es gibt kein selbst registrierbares Verzichtsartefakt.
- **AC-23:** Einschalten in Loose Ends. Given der Plugin-Release mit 2a ist installiert / When `openspec.yaml`
  den Abschnitt `evidence_checks` mit `phase8_complete` (`verifier: xcresult_proof`, `file: simulator-run.txt`) und
  `exempt_paths: ["LooseEnds/Mac/*"]` laut obiger Form enthält / Then liest `scripts/test_evidence_config.py` die Datei
  und bestätigt Form und Inhalt, und ein bewusster Fehlversuch wird abgelehnt: die Gate-Prüfung des installierten
  Plugins (`evidence_gate.check_evidence("phase8_complete", …)`) für einen Wegwerf-Workflow in Loose Ends, in dem eine
  Gate-Datei geändert ist und kein Beleg liegt, liefert eine Ablehnung, die den fehlenden Beleg nennt (nicht eine
  Config-Ablehnung).
- **AC-24:** Ehrlicher Beleg wird akzeptiert. Given das Gate ist in Loose Ends eingeschaltet und derselbe
  Wegwerf-Workflow wie in AC-23 / When `scripts/sim.sh test-proof <Klasse>` im Simulator einen echten Beleg zu einer
  bestehenden UI-Testklasse erzeugt hat / Then liefert dieselbe Gate-Prüfung keine Ablehnung, ohne `override`.
  Schlägt das an einem ehrlichen Beleg fehl, wird das Gate repariert, nicht umgangen. Der Pilot am nächsten echten
  UI-Ticket bleibt offener Punkt in #145 (außerhalb dieses Workflows, weil er ein anderes Ticket braucht).

## Ausnahmen

- Keine Gate-Datei geändert: kein Beleg (Doku, Skripte, Tests; AC-13).
- `exempt_paths` für Bereiche ohne Simulator-UI-Test, in Loose Ends `LooseEnds/Mac/*` (AC-14).
- Sonst nur Hennings getipptes `override` (AC-22). Fast-Track, Spikes und Doku-Tickets ohne Gate-Datei laufen
  durch Regel 1, ohne Sonderpfad.
- Verbreitung heute: 22 von 81 Artefaktordnern haben einen `simulator-run.txt`; ohne diese Ausnahmen würde das Gate
  die Mehrheit der Tickets blockieren.

## Fälschungsschutz und Grenzen (offen benannt)

Der Schutz ist **relativ**, nicht absolut (Entscheidung 2026-10-01): Wer vollen Shell-Zugriff hat, kommt an jeden
Schlüssel, den das Werkzeug liest. Deshalb gilt das Ziel „aufwendiger als der ehrliche Lauf, und es fällt auf":

- Prüfsummen binden den Beleg an den Arbeitsbaum; Codeänderung nach dem Lauf entwertet ihn.
- Ergebnis und Zähler werden aus dem Original-Bündel neu abgeleitet; ein Abtippen von `Passed` genügt nicht.
- Schreibsperre (2b) schließt den bequemsten Weg, die Textdatei von Hand zu schreiben.
- **Restlücke, bewusst akzeptiert:** Ein selbst gebautes, vollständiges `run.xcresult` beweist das Gate nicht als
  unecht. Das Bündel ist nicht signiert; eine Signatur wurde verworfen, weil der Schlüssel für den Agenten lesbar wäre.
- Zielbild später: das Gate fährt den Lauf selbst, oder die CI wiederholt ihn (siehe Alternative).

## Alternative

**CI spielt die im Beleg genannte Testklasse auf dem PR selbst durch, das Gate prüft nur den grünen Check
(`gh pr checks`).** Vorteil: lokal nicht fälschbar, ca. 60 Plugin-LoC, kein `xcresulttool` lokal nötig, läuft auch
auf Linux. Sie kippt die Tech-Lead-Entscheidung vom 2026-10-01 in #145 („Gate leitet lokal aus `run.xcresult` ab",
„Gate fährt selbst = später") und dreht den Ablauf um: der PR müsste vor Phase 8 stehen, und jedes Ticket kostet
CI-Minuten (UI-Lauf heute ca. 4 bis 8 Minuten). **Nicht jetzt:** das lokale Gate schließt die Lücke sofort und bleibt
als erste Stufe sinnvoll; der CI-Nachlauf ist als Zielbild in #145 festgehalten und kann später zusätzlich kommen.

## Test Plan

- **Plugin, Schnitt 2a und 2b (gebaut, PR #449):** `tests/test_evidence_gate_447.py` mit temporärem Projektbaum und einem Stub für
  `xcresulttool` (Skript im `PATH` mit festen JSON-Ausgaben). Fälle: AC-1 bis AC-18, jeder als eigener Test, darunter
  fehlender Beleg, veralteter Hash, fehlende Datei, `Failed`/`Unbekannt`, 0 Tests, falsche `summary.json`-Prüfsumme,
  fehlendes Bündel, abweichende Neuableitung, Zusatzfelder ohne Folge, `xcresulttool` fehlt, Timeout, Symlink,
  leere Konfiguration, `complete`/`finish`.
  Darin auch Schnitt 2b: Write/Edit auf Beleg und Bündel blockiert,
  Bash-Umleitungen blockiert, `scripts/sim.sh test-proof …` und lesende Befehle erlaubt (AC-19, AC-20).
- **Drift (AC-21):** `scripts/test_evidence_config.py` hält `sim_proof.is_gated_code_path` gegen
  `is_gated_code_path` des installierten Plugins mit der Loose-Ends-Konfiguration und `fnmatch` auf
  `evidence_checks.exempt_paths`; ohne installiertes Plugin (CI) übersprungen.
- **Loose Ends, Konfiguration (AC-23):** `scripts/test_evidence_config.py` (`python3 -m unittest`) liest
  `openspec.yaml` und prüft `verifier`, `file` und `exempt_paths` in der Form des Plugins.
- **Fehlversuch und ehrlicher Beleg (AC-23, AC-24):** Wegwerf-Workflow in Loose Ends, Aufruf der Gate-Prüfung des
  installierten Plugins einmal ohne Beleg, einmal nach `scripts/sim.sh test-proof <Klasse>`; die wörtlichen
  Ausgaben gehen ins Adversary-Protokoll. Danach wird der Wegwerf-Workflow entfernt.
- Keine UI-Tests der App: das Werkzeug hat keine Oberfläche, die UI-Testklassen dienen nur als Eingabe für den Pilot.

## Risiken

1. **Gate wirkt auf jeden Abschluss in Loose Ends** (Risiko MEDIUM). Gegenmittel: Opt-in je Projekt, Ausnahmen
   (AC-13, AC-14), Pilot an genau einem Ticket, Kill-Switch durch Entfernen des Abschnitts in `openspec.yaml`.
2. **Zu strenges Gate lehnt ehrliche Belege ab.** Deshalb semantischer Vergleich (AC-9), keine Bindung an `head:`
   (AC-12), Obermenge im Beleg erlaubt.
3. **Drift Erzeuger/Gate.** `sim_proof.py` spiegelt `is_gated_code_path` aus Plugin 3.34.0; das Plugin kennt
   inzwischen `is_colocated_test_file`. Abgesichert durch AC-21.
4. **`xcresulttool` nur auf macOS mit Xcode.** Auf Linux-CI nicht verfügbar; das Gate läuft lokal und lehnt dort
   mit klarer Meldung ab (AC-10), statt zu raten.
5. **Format ändert sich** (Schema 0.4.0 ist versioniert, nicht öffentlich dokumentiert). Fehlende Felder führen
   zur Ablehnung, nie zum Durchlassen.
6. **Reihenfolge:** Plugin 3.41.0 überliest `evidence_checks` (geprüft 2026-10-22), der Abschnitt darf also vor
   dem Release stehen. AC-23 und AC-24 brauchen aber das installierte Release mit #447 (Version nach 3.41.0).
8. **Falsche Form sperrt alles.** Das Plugin prüft die Config vor dem `override`; eine kaputte Form ließe keinen
   Abschluss mehr zu. Gegenmittel: `scripts/test_evidence_config.py` prüft die Form des Plugins, nicht eine eigene.
9. **Latente Drift, heute ohne Fall:** Das Plugin verlangt eine `.swift`-Datei in einem Unterordner namens `tools/`,
   `tests/`, `spec/` o. ä. (z. B. `Measurement/tools/X.swift`), `sim_proof.py` schreibt sie nicht in den Beleg. Solch
   eine Datei gibt es heute nicht; entsteht eine, scheitert der ehrliche Beleg sichtbar und `sim_proof.py` wird
   angepasst. Ebenso nimmt das Plugin `base_commit`, wenn er jünger als der merge-base ist.
7. **Schreibsperre vs. Erzeuger:** Die Sperre sieht nur Befehlstexte, die den Pfad nennen; `sim.sh` schreibt intern
   und wird nicht gesehen (gewollt, AC-20).

## Abnahme

Stufe 1 (Tests) und Stufe 2 (echter Durchlauf des Gates: bewusster Fehlversuch und ehrlicher Beleg, AC-23/AC-24) sind
Pflicht. Stufe 3 entfällt: `openspec.yaml` steht nicht in der Geräteliste von `CLAUDE.md`, das Plugin ist kein
App-Pfad. Abschlussbericht-Satz: „Kein Pfad der Geräteliste berührt."

## Side-Effects

- Geändert in Loose Ends: `openspec.yaml`, neu optional `scripts/test_evidence_config.py`. Im Plugin-Repo: siehe Tabelle.
- Von da an kann ein Abschluss in Loose Ends an einem fehlenden Beleg scheitern; das ist die Absicht.
- Neue Permissions (Info.plist)? Nein. AppStorage-Keys? Nein. Audio-Dateien? Nein. Keine neue Abhängigkeit.

## Definition of Done

- [ ] AC-1 bis AC-24 erfüllt, jeder bewusste Fehlversuch mit wörtlicher Ausgabe im Abschlussbericht
- [ ] Plugin: `tests/test_evidence_gate_447.py` grün (#447), Release mit #447 veröffentlicht und installiert
- [ ] Loose Ends: `openspec.yaml` eingeschaltet, Konfigurationsprüfung grün
- [ ] Fehlversuch und ehrlicher Beleg am Wegwerf-Workflow mit wörtlicher Ausgabe; Pilot am nächsten UI-Ticket als offener Punkt in #145
- [ ] Schnitt 3 (Doku) als offener Punkt von #145 sichtbar; PR verweist mit `Refs #145`, nicht `Closes`
- [ ] Jeder Commit kompiliert, CI grün

## Changelog

- 2026-10-22: An das gebaute Plugin (#447, PR #449) angeglichen: Konfigurationsform (`verifier`/`file`, `exempt_paths` eine Ebene höher als `fnmatch`-Muster), Meldungs-ACs auf Sinn statt Wortlaut (AC-1, 2, 6, 10), Testdatei `test_evidence_gate_447.py`; AC-24 vom Pilot am nächsten Ticket auf den ehrlichen Beleg am Wegwerf-Workflow umgestellt (der Pilot bleibt offen in #145), Risiken 6, 8, 9.
- 2026-10-22: Spec aus der Analyse in `docs/context/feat-145-s2-gate.md` geschrieben (Schnitt 2 von #145; Plugin-Ticket henemm/agent-os-openspec#447).
