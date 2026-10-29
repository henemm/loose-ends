---
entity_id: feat-88-b1-ablage
type: feature
created: 2026-10-28
updated: 2026-10-28
status: draft
---

# Spec: #88 Schnitt B1a (ohne Gerät) — der Laborläufer findet Hennings Rohsatz-Datei und scheitert laut

**Status:** draft · **Workflow:** 88-b1-ablage · **Erstellt:** 2026-10-28 · **Aktualisiert:** 2026-10-28

## Freigabe

- [ ] Freigegeben

## Problem
Schnitt A (PR #733) kann Hennings echte Rohsätze lesen und auswerten, aber der Laborläufer kommt nicht an die
Datei `docs/reference/loose-ends-rawtexts.json`: `Corpus.url` sucht nur im Bundle, neben der Quelle in
`Measurement/` und in Documents, nie in `docs/reference/`. Schlimmer: `MeasurementRunner` wandelt jeden Ladefehler
mit `try?` in eine leere Liste. Ein Lauf mit `--corpus loose-ends-rawtexts` ergäbe „Korpus: 0 Sätze“ im Zustand
„Bereit“, und niemand merkt, dass nichts gemessen wird. Das gilt für jeden Korpus, nicht nur diesen.

## Zweck
Nach diesem Schnitt gibt es für jeden Korpus nur zwei Ausgänge: Einträge, oder ein benannter Grund, der in der
Labor-App steht. Die Rohsatz-Datei liegt an einem Ort (`docs/reference/`), das Lab-Ziel bindet sie ein, wenn sie
da ist, und fehlt sie, sagt der Läufer das.

**Ohne Modell:** kein Modell im Schnitt (Laden, Melden, Ablegen). Die Rohsatz-Datei selbst zu holen (Export aus
Hennings Store) und der Laborlauf sind Schnitt B1b/B2 und laufen nur nach seinem wörtlichen „jetzt ist ein Test
möglich“.

## Quelle
- **Dateien:** `Measurement/Corpus.swift`, `LooseEndsLab/MeasurementRunner.swift`, `LooseEndsLab/LabApp.swift`
  (nur gelesen, `statusText` zeigt `.paused` schon an), `project.yml` (Ziel `LooseEndsLab`), `scripts/sim.sh`
  (`cmd_lab`), `LooseEndsTests/CorpusTests.swift`, `docs/context/88-b1-ablage.md`
- **Bezeichner:** `Corpus.load`, `Corpus.url`, neu `Corpus.loadReport`

## Entscheidung zur Ablage (hier festgelegt)
Die Datei bleibt in `docs/reference/` (wie Schnitt A und `MeasurementData`); das Lab-Ziel bindet sie als optionale
Ressource ein (`optional: true`). Verworfen: Export nach `Measurement/` (zwei Orte, landet auch in beiden
Test-Bündeln) und Kopie nach Documents per `devicectl` (Gerätezugriff, gehört zu B2). Keine ADR wird gekippt.

## Acceptance Criteria

- **AC-1:** Ergebnis statt Ausnahme. Given ein Korpusname / When `Corpus.loadReport(fileName:)` läuft / Then
  liefert es entweder die Einträge oder genau einen benannten Grund, nie beides und nie still eine leere Liste.
  `Corpus.load` bleibt unverändert und wirft weiter.
- **AC-2:** Datei fehlt. Given ein Name ohne Datei in Bundle, neben der Quelle, in `docs/reference/` oder in
  Documents / When `loadReport` läuft / Then ist der Grund „fehlt“ und der Text nennt den Korpusnamen
  („Korpus <name> fehlt …“).
- **AC-3:** Datei kaputt. Given eine vorhandene Datei, die kein lesbares Korpusformat ist / When `loadReport`
  läuft / Then ist der Grund „unlesbar“, mit Korpusname und der Fehlerart, ohne Inhalt der Datei.
- **AC-4:** Datei leer. Given eine vorhandene Datei, die gültig ist, aber null Einträge ergibt (leere Liste) /
  When `loadReport` läuft / Then ist der Grund „leer“ mit Korpusname.
- **AC-5:** Datei in Ordnung. Given eine gültige Datei mit Einträgen / When `loadReport` läuft / Then liefert es
  dieselben Einträge wie `Corpus.load`, ohne Grund.
- **AC-6:** Suchort `docs/reference/`. Given eine Datei `<name>.json` nur in `docs/reference/` des eigenen
  Arbeitsstands (neben `Measurement/`) / When `Corpus.url(fileName:)` sucht / Then findet es sie; Bundle bleibt
  vorrangig, danach `Measurement/`, `docs/reference/`, Documents. Die bisherigen Korpusse laden unverändert
  (`CorpusTests`).
- **AC-7:** Läufer meldet laut. Given ein Korpus mit Grund / When `MeasurementRunner` startet / Then steht der
  Grund im Zustand `.paused(<Text>)` (die Labor-App zeigt ihn als Statuszeile), im Protokoll als Ereignis
  `korpus` und im `Logger`; das `try?` an dieser Stelle entfällt. `start` auf einem solchen Läufer misst nichts,
  schreibt aber ein Ereignis, statt still zurückzukehren.
- **AC-8:** Lab-Ziel bindet die Datei optional. Given `project.yml` / When `generate` läuft mit und ohne
  `docs/reference/loose-ends-rawtexts.json` / Then gelingt es in beiden Fällen; nur mit Datei steht sie im
  Lab-Bündel, und nie in `LooseEnds`, `LooseEndsTests` oder `LooseEndsUITests`. In der CI (ohne Datei) bleibt
  „Generate leaves the tree clean“ grün.
- **AC-9:** Worktree-Falle geschlossen. Given `sim.sh lab` aus einem Worktree, in dessen `docs/reference/` die
  Datei fehlt, im Hauptordner aber liegt / When es vor `generate` läuft / Then wird sie aus dem Hauptordner
  verlinkt (gitignoriert, nie überschrieben, nie bei vorhandener eigener Datei); fehlt sie auch dort, läuft der
  Bau weiter und der Läufer meldet AC-2 auf dem Gerät.
- **AC-10:** Keine Sätze in Meldungen. Given Kunstdaten mit Marker-Wörtern / When `loadReport` einen Grund
  bildet / Then enthält der Text keines davon; nur Name, Art, Zahl.

## Nicht in diesem Schnitt
- Das Export-Skript, das Hennings Store liest, sein Test gegen eine Wegwerf-Datenbank und die Aufrufbeschreibung
  (B1b, eigener Workflow). Das Ausführen gegen seinen Store gehört zu B2.
- Laborlauf, `device-status`, `lab`-Installation oder jede andere Aktion auf Hennings Geräten.
- Änderungen an `LabApp.swift` (die Statuszeile zeigt `.paused` schon), am Produktpfad oder an
  `RawSentenceColumn`.
- Jede echte Rohsatz-Datei im Repository, in Artefakten oder Kommentaren.

## Abhängigkeiten

| Baustein | Art | Zweck |
|----------|-----|-------|
| `Corpus.entries(from:)` | Funktion | liest alle drei Formate, bleibt unverändert |
| `MeasurementRunner`, `LabView.statusText` | Klasse, View | zeigt `.paused` als Zeile |
| #71 Schnitt 2a (`countRefusals`) | gemergt | ändert denselben Läufer; vor dem Merge `origin/main` erneut prüfen |
| xcodegen `optional: true` | Werkzeug | Quelle darf fehlen |

## Umfang

### Betroffene Dateien

| Datei | Änderungsart | Beschreibung |
|-------|---------------|--------------|
| `Measurement/Corpus.swift` | MODIFY | `loadReport`, Grund-Typ mit Text, Suchort `docs/reference/` in `url` |
| `LooseEndsLab/MeasurementRunner.swift` | MODIFY | `try?` ersetzen, Grund in Zustand, Protokoll, `Logger`; `start` meldet |
| `project.yml` | MODIFY | Lab-Quelle `docs/reference/loose-ends-rawtexts.json` mit `optional: true` |
| `scripts/sim.sh` | MODIFY | `cmd_lab` verlinkt die Datei aus dem Hauptordner vor `generate` |
| `LooseEndsTests/CorpusTests.swift` | MODIFY | Tests zu AC-1 bis AC-6 und AC-10 |

### Geschätzter Umfang
- Dateien: **5**, innerhalb der Grenze. Zeilen: etwa +120 / −10.

## Technische Umsetzung
`Corpus.loadReport(fileName:)` ruft `url` und `entries` auf und fängt dort die Fehler: `CocoaError.fileNoSuchFile`
wird „fehlt“, jeder andere Fehler „unlesbar“ (nur Typ und Code, nie der Dateiinhalt), null Einträge „leer“. Der
Rückgabewert ist ein Enum mit den Fällen `entries([Entry])` und `problem(Problem)`; `Problem.message` ist der
deutsche Text für die Statuszeile. `url` bekommt `docs/reference/<name>.json` relativ zu `#filePath` als zweiten
Ort neben der Datei in `Measurement/`. Der Läufer setzt bei einem Problem `state = .paused(message)` und schreibt
`log("korpus", message)`; `start` schreibt bei leerem Korpus `log("start", "abgelehnt: …")`. `sim.sh` verlinkt vor
`ensure_project` mit `ln -s`, nur wenn die Datei im Arbeitsstand fehlt und im Hauptordner vorhanden ist.

**Alternativen:** (B) Export nach `Measurement/` und (C) `devicectl` nach Documents, siehe Entscheidung oben.
(D) statt `.paused` ein neuer Zustand `.unusable(String)`: sauberer benannt, verlangt aber eine Änderung an
`LabApp.statusText` (sechste Datei) für nur einen Text; verworfen.

## Testplan

### Automatisierte Tests (TDD RED)
In `CorpusTests.swift`, mit Wegwerf-Dateien in einem temporären Ordner (Kunstdaten, keine echten Sätze):
- [ ] `loadReportMissingFileNamesCorpus` — GIVEN Name ohne Datei / WHEN `loadReport` / THEN Grund „fehlt“ mit Namen (AC-1, AC-2).
- [ ] `loadReportCorruptFileIsUnreadable` — GIVEN Datei mit Müll / THEN „unlesbar“, kein Dateiinhalt im Text (AC-3, AC-10).
- [ ] `loadReportEmptyListIsEmpty` — GIVEN `[]` / THEN „leer“ (AC-4).
- [ ] `loadReportValidMatchesLoad` — GIVEN vorhandener Korpus (`date-title-corpus`) / THEN gleiche Einträge wie `Corpus.load`, kein Grund (AC-1, AC-5).
- [ ] `urlFindsDocsReferenceNextToMeasurement` — GIVEN Datei in `docs/reference/` des Arbeitsstands (im Test angelegt und danach entfernt) / THEN `url` findet sie; bestehende Korpus-Tests bleiben grün (AC-6).
- [ ] `problemMessageNeverContainsSentences` — GIVEN Marker-Wörter in Kunstdaten / THEN keines im Grund-Text (AC-10).
- [ ] Skript-Test `scripts/test_sim_lab_link.py` entfällt: AC-8 und AC-9 sind Skript-/Projektverhalten und werden in Stufe 2 am echten Lauf belegt (unten), nicht an einem Aufbau, der seinen Ausgangszustand selbst setzt.

Der Läufer (AC-7) sitzt im Lab-Ziel und ist nicht in den Tests; sein Nachweis ist der Simulatorlauf unten.

### Abnahme Stufe 2 (Durchlauf, Pflicht)
1. `./scripts/sim.sh generate` ohne Datei, danach mit einer selbst gebauten Wegwerf-Datei in `docs/reference/`:
   beides gelingt; Lab-Bündel enthält die Datei nur im zweiten Fall (AC-8).
2. Labor-App für den Simulator bauen und mit `--corpus loose-ends-rawtexts` starten, erst ohne Datei: Screenshot
   zeigt die Zeile „Korpus loose-ends-rawtexts fehlt …“ und „Messen“ tut nichts; dann mit Wegwerf-Datei: Zeile
   „Sätze 0 von N“ (AC-2, AC-5, AC-7). Screenshots werden geöffnet und beschrieben.
3. `sim.sh lab` wird bis zur Verlinkung nur im Trockenlauf geprüft (Hauptordner-Datei vorhanden / fehlt /
   eigene Datei da); **es installiert nichts auf Hennings Geräten** (AC-9).
4. Danach die ganze Unit-Suite im Simulator und die CI.

Keine UI-Tests: kein Produktcode, keine App-View. Geräteliste: `project.yml` steht auf ihr, Stufe 3 fällt aber mit
B2 zusammen (Laborlauf #88/#71, ein gemeinsames Wort von Henning). **Nichts auf Hennings Geräten vor seinem
„jetzt ist ein Test möglich“.** Der Abschlussbericht sagt das ausdrücklich.

## Definition of Done

- [ ] AC-1 bis AC-10 erfüllt, belegt durch Tests und Simulatorlauf
- [ ] Alle Unit-Tests grün (`./scripts/sim.sh sim-unit`), CI grün, PR gemergt; #88 bleibt mit B1b/B2 offen
- [ ] Hauptordner nachgezogen und Projekt neu erzeugt
- [ ] Keine echte Rohsatz-Datei und kein echter Satz in Repository, Artefakten oder Kommentaren
- [ ] Nichts auf einem Gerät von Henning gestartet, sein Store nicht gelesen
- [ ] `CLAUDE.md` (Zeile zu `Measurement/Corpus`/Läufer) und Issue #88 aktualisiert

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Messwerkzeug, kein Produktpfad, keine neue Abhängigkeit; keine bestehende ADR wird gekippt.

## Changelog

- 2026-10-28: Spec aus `docs/context/88-b1-ablage.md` erstellt. Abweichung von der Analyse: `LabApp.swift`
  entfällt (Anzeige über `.paused`), dafür bleibt es bei 5 Dateien.
