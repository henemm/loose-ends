---
entity_id: spike-71-schnitt-2b2-lab-guardrail
type: feature
created: 2026-10-29
updated: 2026-10-29
status: draft
workflow: feat-71-s2b2-lab-guardrail
---

# Spec: Guardrail-Rate messen, Schnitt 2b-2 — Werkzeug für den iPhone-Lauf (#71)

## Approval

- [ ] Approved

## GitHub Issue

#71 (Spike, Epic #370, Annahme B3). Schnitt 2b-2 von 2b-2 (nach 2a, PR #734, und 2b-1, PR #735). Der Code-PR trägt `Refs #71`, nie `Closes #71`; das Ticket schließt der Datenschritt nach dem Gerätelauf.

## Purpose

Annahme B3: Mehr als 1 % Ablehnung auf Alltagstext ist das Abbruchkriterium. Die Mac-Zahl (2/387 = 0,52 %, obere Wilson-Grenze 1,86 %) liegt mit ihrer Grenze über 1 %, das iPhone hat die neuere Modellgeneration. Läufer (2a) und Auswertung (2b-1) stehen. Es fehlt das Werkzeug, das den Lauf auf dem iPhone ohne Handarbeit treibt:

- ein Skript, das den Gerätekorpus baut (100 heikle Texte + die persönlichen Sätze) und Ergebnisse zählt,
- der Befehl `./scripts/sim.sh lab-guardrail` mit Trockenlauf, der Scheiben fährt, die Ergebnisdatei holt und den Berichttest aus 2b-1 aufruft.

Dieser PR **führt nichts auf einem Gerät aus**. Der Gerätedurchgang und der Datenschritt (Bericht, Rohdaten, B3-Entscheidung) sind ein eigener Schritt nach dem Merge und laufen nur, wenn Henning wörtlich „jetzt ist ein Test möglich“ schreibt (Abschnitt „Gerätedurchgang“).

**Ohne Modell geht es nicht, weil** die Frage lautet, ob das Modell ablehnt; Regeln lehnen nie ab, die Regel-Spalte ist 0 % per Konstruktion (Schnitt 1, `docs/reference/modell-guardrails.md`, „Nulllinie“). Der Schnitt führt kein Modell ein, er misst das bestehende.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Messwerkzeug (Skripte), kein Produktpfad
- **Rationale:** Handlauf-Befehl und Hilfsskript; kein Produktverhalten, kein Schema, keine Berechtigung. Gekippte ADR: keine.

## Source

- **File:** `scripts/sim.sh`
- **Identifier:** `cmd_lab_guardrail` (neu), Aufruf `lab-guardrail [--dry-run]`

Zusätzlich: `scripts/guardrail_corpus.py` (neu), `scripts/test_guardrail_corpus.py` (neu).

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| 2a (PR #734): `--count-failures`, `--exit-when-done`, `Corpus.url` mit `Documents/` | module | Läufer zählt Ablehnung als Ergebnis und liest den Korpus aus dem Container |
| 2b-1 (PR #735): `IphoneGuardrailReportTests` | test | Berichttest, braucht `LOOSEENDS_GUARDRAIL_IPHONE_RESULT`, `_CORPUS`, `_OUT`, `_LOCAL` |
| `cmd_lab_latency`, `lab_latency_launch`, `cmd_lab_fetch`, `require_device`, `signed_build`, `LAB_BUNDLE` | script | Vorlage und Bausteine für Bau, Start, Holen |
| `cmd_real_model_guardrail` | script | Vorbild für Quelle `LOOSEENDS_FOCUSBLOX_CORPUS`, Scratch-Pfad und Rohdatenpfad |
| `Measurement/guardrail-corpus.json` | data | 100 heikle Texte, unverändert übernommen |
| `docs/reference/focusblox-corpus.json` (gitignored, nur im Hauptordner) | data | 287 persönliche Sätze; nie ins Repo, nie ins Bündel |
| `xcrun devicectl device copy to` | tool | Korpusdatei in den Container der Labor-App |
| Hennings Wort „jetzt ist ein Test möglich“ | Freigabe | Voraussetzung für den Gerätedurchgang, nicht für den Code |

Recherche zu `copy to` (2026-10-29): `xcrun devicectl device copy to --help` (Xcode 27) und Apple-Forum https://developer.apple.com/forums/thread/765386: `--user mobile --domain-type appDataContainer --domain-identifier <Bundle-ID> --source <Datei> --destination Documents/<Datei>`; `Documents/` gehört in `--destination`, nicht in die Kennung. Ob die Datei im Container landet, zeigt nur der Gerätedurchgang.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/guardrail_corpus.py` | CREATE | `build` und `count` |
| `scripts/test_guardrail_corpus.py` | CREATE | Selbsttest (Python, ohne Fremdpakete, `-I`-tauglich) |
| `scripts/sim.sh` | MODIFY | `cmd_lab_guardrail`, Dispatch `lab-guardrail`, Kopfkommentar |

Nicht angefasst: `Shared/`, `LooseEndsLab/`, `Measurement/`, `LooseEndsTests/`, `project.yml`, jede Berechtigungs- oder Info.plist-Datei. Geräteliste: kein Produktpfad berührt.

### Estimated Changes

- Files: 3
- LoC: ca. +270 (Skript +60, Selbsttest +120, `sim.sh` +90). Das liegt am oberen Rand von ±250; Teilung vorgesehen, falls die Zählung in der Implementierung darüber liegt: 2b-2a = `guardrail_corpus.py` + Selbsttest, 2b-2b = `sim.sh`-Befehl.

## Implementation Details

### 1. Gerätekorpus und Zählung (`scripts/guardrail_corpus.py`)

- `build <focusblox.json> <ziel.json>`: liest `Measurement/guardrail-corpus.json` (Einträge `id`, `lang`, `text`, `form`) und die FocusBlox-Datei (`lang`, `rawText`). Alltag: `id` = `alltag-<Index>` (Index = Position in der FocusBlox-Datei ab 0, wie am Mac), `text` = `rawText`, `form` = `alltag`.
  - Bricht mit Fehlerstatus und Meldung ab, **bevor etwas geschrieben wird**, wenn: der aufgelöste Zielpfad im Repo liegt (Wurzel per `git rev-parse --show-toplevel` im Verzeichnis des Skripts); die Zahl heikler Einträge ≠ 100 ist; eine Id doppelt vorkommt (N1 aus dem Prüfdialog 2b-1); eine Id weder mit `gr-` noch mit `alltag-` beginnt (N2: sonst gälte ein persönlicher Satz als `heikel` und bliebe in den Rohdaten).
  - Schreibt nur nach `<ziel.json>`. Gibt am Ende Zahlen aus (heikel, Alltag, gesamt), **nie einen Satz**.
- `count <ergebnis.json>`: gibt die Zahl der Aufrufe aus, die als gemessen zählen: `error` leer, oder `errorKind` ist `guardrail` oder `refusal` (gleiche Regel wie `countsAsMeasured(countRefusals: true)`); je Eintrag × `runIndex` höchstens einmal, auch wenn die Datei nach einer Wiederholung mehr Ergebnisse enthält. `rateLimited`, `timeout` und andere Fehler zählen nicht.

### 2. Befehl `lab-guardrail` (`scripts/sim.sh`)

Kopfkommentar wie bei `lab-latency`: nur nach Hennings wörtlichem „jetzt ist ein Test möglich“, fasst nur die Labor-App an. Ablauf von `cmd_lab_guardrail [--dry-run]`:

1. Korpus mit `guardrail_corpus.py build` nach `${TMPDIR:-/tmp}/loose-ends-71-guardrails/guardrail-geraet.json` bauen. Quelle: `LOOSEENDS_FOCUSBLOX_CORPUS`, sonst der Hauptordner-Pfad wie bei `real-model-guardrail`.
2. **Meldung vor jedem Gerätezugriff:** Zahl der Aufrufe (Texte × 2, bei 387 Texten 774), geschätzte Dauer (Median warm 4,83 s nach `docs/reference/modell-latenz.md`, rund 62 Minuten reine Modellzeit; Obergrenze 25 s je Aufruf), Hinweis „iPhone entsperrt lassen, im selben WLAN“. Mit `--dry-run` endet der Befehl hier mit Status 0, ohne `require_device`, Bau oder `devicectl`.
3. `require_device`, `ensure_project`, `signed_build` der Labor-App, Prüfung der Kennung gegen `$LAB_BUNDLE` wie in `cmd_lab_latency`. **Keine Deinstallation** (der Ergebnisname `guardrail-iphone` ist neu, der Läufer setzt sonst fort — erwünscht).
4. Korpusdatei per `devicectl device copy to` nach `Documents/guardrail-geraet.json`.
5. Scheiben: Start mit `--measure --corpus guardrail-geraet --runs 2 --result guardrail-iphone --count-failures --exit-when-done --context-words Computer,Telefon,Haus,Garten,Unterwegs,Besorgung` unter `timeout` (Scheibe 20 Minuten, höchstens 6 Scheiben); nach jeder Scheibe Ergebnisdatei holen und mit `guardrail_corpus.py count` prüfen. Schleife bis alle Aufrufe gemessen sind oder die Höchstzahl erreicht ist (Abbruch mit Meldung, Stand bleibt auf dem Gerät und in der geholten Datei, ein erneuter Aufruf setzt fort). Gesperrtes Gerät (`Locked`) beendet sauber mit Hinweis.
6. Ergebnisdatei in das Scratch-Verzeichnis außerhalb des Repos holen; den Berichttest im Simulator mit `TEST_RUNNER_LOOSEENDS_GUARDRAIL_*` laufen lassen (Rohdaten nach `docs/artifacts/71-guardrails/iphone-rohdaten.json`, lokale Zusammenfassung nach `${TMPDIR:-/tmp}/loose-ends-71-guardrails/iphone-auswertung.txt`).

Keine Befehle, die eine `$`-Variable als Programm ausführen; Fehler werden gemeldet, nicht verschluckt (kein `|| true` auf Messwegen außer dem Holen wie in `lab_latency_launch`, dort gefolgt von der Dateiprüfung).

## Gerätedurchgang und Datenschritt (nicht Teil dieses PR)

Nach Merge, **nur auf Hennings wörtliches „jetzt ist ein Test möglich“**, per AskUserQuestion mit Dauer und Umfang vorher erfragt. Die Freigabe vom 2026-10-28 ist verbraucht oder ersetzt keine neue Frage. Reihenfolge („Bereit, bevor ich Henning rufe“): Trockenlauf grün, Labor-App gebaut, Korpus gebaut; die Nachricht, die Henning ruft, startet den Befehl. Seine einzige Aufgabe: iPhone entsperrt lassen. Danach der Datenschritt in einem eigenen Commit: iPhone-Spalte in `docs/reference/modell-guardrails.md` (Zahlen wörtlich aus dem Berichttest), `iphone-rohdaten.json` (774 Proben, Alltag ohne Text), B3-Entscheidung in `docs/project/06-annahmen-und-experimente.md` mit Zahl und 1-%-Schwelle; Ticket #71 schließen. Über der Schwelle: Folgeticket „Modell hat abgelehnt“.

## Acceptance Criteria

- **AC-1:** `guardrail_corpus.py build` erzeugt aus einer erfundenen FocusBlox-Datei (3 Sätze) und `Measurement/guardrail-corpus.json` eine Datei mit 103 Einträgen; Alltag hat `id` `alltag-0` bis `alltag-2` und `form` `alltag`; das Format (`id`, `lang`, `text`, `form`) ist das, das `Corpus.entries(from:)` liest. Die Standardausgabe enthält keinen Satz.
- **AC-2:** `build` bricht mit Fehlerstatus ab und legt keine Zieldatei an, wenn der Zielpfad im Repo liegt, wenn die Zahl heikler Einträge ≠ 100 ist, bei doppelter Id und bei einer Id ohne Präfix `gr-` oder `alltag-`.
- **AC-3:** `guardrail_corpus.py count` zählt je Eintrag × Durchlauf höchstens einmal und nur Erfolge, `guardrail` und `refusal`; `rateLimited` und `timeout` zählen nicht; ein doppeltes Ergebnis desselben Eintrags und Durchlaufs zählt einmal.
- **AC-4:** `./scripts/sim.sh lab-guardrail --dry-run` baut die Korpusdatei außerhalb des Repos, gibt Aufrufzahl, geschätzte Dauer und „entsperrt“ aus und endet mit Status 0, ohne `require_device`, `devicectl` oder Bau; `bash -n scripts/sim.sh` meldet keinen Fehler.
- **AC-5:** Statische Prüfung in `scripts/test_guardrail_corpus.py` über den Text von `cmd_lab_guardrail`: kein `device uninstall`, keine andere Kennung als `$LAB_BUNDLE`; enthält `--count-failures`, `--runs 2`, `--result guardrail-iphone`, `--exit-when-done`, `device copy to` mit `--domain-identifier "$LAB_BUNDLE"` und `--destination Documents/guardrail-geraet.json`; schreibt Rohdaten nur nach `docs/artifacts/71-guardrails/` und die lokale Zusammenfassung nur unter `${TMPDIR`; `require_device` steht erst nach der Meldung mit Zahl und Dauer.
- **AC-6:** Simulator-Durchlauf der Kette ohne Gerät: eine Wegwerf-Ergebnisdatei (Aufrufe aus dem gebauten Wegwerf-Korpus, eine Ablehnung in der Alltagsmenge) außerhalb des Repos geht durch `count` (Soll erreicht) und durch den Berichttest aus 2b-1 im Simulator; die Rohdaten enthalten kein Alltagswort, die lokale Zusammenfassung den Treffer.
- **AC-7:** Der Code-PR enthält genau die drei Dateien der Scope-Tabelle, nichts läuft auf einem Gerät (kein `devicectl`-Aufruf im Test- oder Beleglauf; der Selbsttest nutzt für `DEVICECTL` eine Attrappe, die jeden Aufruf als Fehler meldet), und der PR nennt `Refs #71`.

## Test Plan

### Automated Tests (TDD RED)

Python-Selbsttest: `python3 -I scripts/test_guardrail_corpus.py`. Keine Gerätetests, keine UI-Tests (kein sichtbarer Teil).

- Test: GIVEN erfundene FocusBlox-Datei mit 3 Sätzen WHEN `build` THEN 103 Einträge, `alltag-0` bis `alltag-2`, `form` `alltag`, Schlüssel `id`, `lang`, `text`, `form` (AC-1)
- Test: GIVEN Standardausgabe von `build` WHEN geprüft THEN enthält keinen der erfundenen Sätze (AC-1)
- Test: GIVEN Zielpfad im Repo / ≠ 100 heikle / doppelte Id / Id ohne Präfix WHEN `build` THEN Fehlerstatus, Datei nicht angelegt (AC-2)
- Test: GIVEN Ergebnisse mit Erfolg, `refusal`, `guardrail`, `rateLimited`, `timeout` und einem Doppel WHEN `count` THEN nur Erfolg, `refusal`, `guardrail`, Doppel einmal (AC-3)
- Test: GIVEN `lab-guardrail --dry-run` mit `LOOSEENDS_FOCUSBLOX_CORPUS` auf erfundene Datei und `DEVICECTL` als Attrappe WHEN ausgeführt THEN Status 0, Ausgabe enthält die Aufrufzahl und „entsperrt“, Attrappe nie aufgerufen (AC-4, AC-7)
- Test: GIVEN Text von `cmd_lab_guardrail` WHEN geprüft THEN die Zusicherungen von AC-5

### Simulator-Durchlauf (Pflicht vor der Übergabe)

Kette wie AC-6 im Simulator (`./scripts/sim.sh sim-unit GuardrailReportTests` mit gesetzten `TEST_RUNNER_…`-Variablen) mit Wegwerf-Dateien außerhalb des Repos; `grep` belegt: kein Alltagswort in den Rohdaten, Treffer in der lokalen Zusammenfassung. Gerät: nichts.

## Alternativen

- **A. B3 allein auf der Mac-Zahl entscheiden, iPhone-Lauf streichen:** verworfen, obere Grenze 1,86 % liegt über der Schwelle und das iPhone hat die neuere Modellgeneration. Gekippt würde die Annahme, dass Mac und iPhone getrennt zählen.
- **B. Korpus als Bündelressource der Labor-App statt `copy to`:** kein Transfer nötig, aber persönliche Sätze lägen im Bau. Verworfen (Datenschutz).
- **C. Nur die 100 heiklen Texte:** ein Treffer wäre schon 1 %, die Schwelle trüge nicht.
- **D. Zählung in Swift statt Python:** die Schleife in `sim.sh` braucht die Zahl vor dem Simulator-Lauf; ein Zähler in Python ist dort einfacher. Auswertung (Wilson-Grenze, Rate) bleibt allein in Swift, damit es nur eine Quelle gibt.
- Gekippte ADR: keine.

## Definition of Done

- [ ] AC-1 bis AC-7 erfüllt, jedes durch Selbsttest, Simulator-Durchlauf, `grep` oder Dateiliste belegt
- [ ] `python3 -I scripts/test_guardrail_corpus.py` grün, `bash -n scripts/sim.sh` ohne Fehler
- [ ] Simulator-Durchlauf der Kette belegt; nichts auf einem Gerät gelaufen
- [ ] PR mit `Refs #71`; Gerätedurchgang und Datenschritt als nächster Schritt benannt

## Changelog

- 2026-10-29: Initial (Schnitt 2b-2), aus Vorlage der geteilten Spec 2b und Prüfdialog 2b-1 (N1, N2)
