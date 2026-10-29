# Context: 88-b1-ablage

## Request Summary
#88 Schnitt B, Teil B1 (ohne Gerät): Die Korpusdatei mit Hennings echten Rohsätzen muss vom Laborläufer gefunden
werden, ein leerer oder fehlender Korpus darf nicht still durchlaufen, und der Export-Weg wird beschrieben. B2
(Export aus Hennings Store, Laborlauf, Bericht) bleibt offen bis zu seinem „jetzt ist ein Test möglich“, im selben
Durchgang wie #71.

## Stand vor dieser Arbeit
- Schnitt A gemergt (PR #733): `Measurement/RawSentenceColumn.swift`, drittes Format in `Corpus.entries(from:)`
  (erkannt am Inhalt: erstes Objekt trägt `rawText`, `titleBefore`, `capturedAt`), Bericht `RawSentenceReportTests`.
- `.gitignore` führt `docs/reference/loose-ends-rawtexts.json`. Die Datei existiert noch nicht.

## Related Files
| File | Relevance |
|------|-----------|
| `Measurement/Corpus.swift:147-182` | `load(fileName:)` und `url(fileName:)`: sucht nur Bundle, Datei neben `Corpus.swift` (`Measurement/`) und Documents. `docs/reference/` kommt nicht vor. |
| `LooseEndsLab/MeasurementRunner.swift:65` | `entries = (try? Corpus.load(...)) ?? []`: ein fehlender oder kaputter Korpus ergibt 0 Einträge ohne Fehler. `start` kehrt bei leerem Korpus still zurück. Das ist ein `try?`, das Fehler verschluckt (Projektregel). |
| `LooseEndsLab/LabApp.swift` | reicht `--corpus` an den Läufer; zeigt Fehlversuche, aber keinen Korpusfehler |
| `LooseEndsTests/MeasurementData.swift` | findet gitignorierte Dateien in `docs/reference/` (eigener Arbeitsstand, dann Hauptordner); `scripts/measurement_status.py` spiegelt das |
| `LooseEndsTests/CorpusTests.swift:150-165` | bestehende Tests für Ladepfad und `--corpus` (unbekannter Name wirft `fileNoSuchFile`) |
| `scripts/export-focusblox-corpus.swift` | Vorbild für einen schreibgeschützten Export aus einem SwiftData-Store (SQLite), Ausgabe gitignoriert |
| `project.yml` (Lab-Target) | Quellen `LooseEndsLab`, `Measurement` und einzelne Shared-Dateien. JSON-Dateien aus `Measurement/` landen als Ressourcen im Lab-Bundle. |

## Existing Patterns
- Auf dem iPhone kommt ein Korpus nur über das Bundle (Dateien in `Measurement/`) oder über Documents der Labor-App
  in den Läufer. Auf dem Mac auch über die Datei neben der Quelle.
- Personendaten liegen gitignoriert in `docs/reference/`. Fehlt die Datei, wird die Messsuite laut übersprungen und
  `measurement_status.py` meldet es.
- Fehler werden geworfen oder protokolliert, nie verschluckt (`Logger`, kein `try?`).

## Befund (Ursache mit Beleg)
1. **Ablage:** `Corpus.url` kennt `docs/reference/` nicht. Selbst mit fertiger Datei fände der Läufer sie weder auf dem
   Mac noch im Lab-Bundle. Der Lauf `--corpus loose-ends-rawtexts` ergäbe `Korpus: 0 Sätze` und endet im Zustand
   `idle`, ohne dass jemand es merkt.
2. **Stilles Scheitern:** `MeasurementRunner.swift:65` wandelt jeden Ladefehler in eine leere Liste. Das gilt für alle
   Korpora, nicht nur diesen.
3. **Export:** Es gibt kein Skript, das Hennings Store liest. Ausführen wäre Zugriff auf sein Gerät (nur auf sein Wort).
   Vorbereitbar: das Skript schreiben und gegen eine selbst gebaute Wegwerf-Datenbank testen, nicht gegen seinen Store.

## Offene Entscheidung für die Analyse
Wie kommt die Datei in den Läufer, ohne ins Repo zu geraten?
- A: Export schreibt nach `docs/reference/` (wie Schnitt A, wie `MeasurementData`); das Lab-Target bindet sie
  als optionale Ressource ein (xcodegen `optional: true`), nur dort, nicht in Test-Bundles.
- B: Export schreibt nach `Measurement/` (gitignoriert); Bundle und Mac-Suche greifen ohne Änderung, aber die Datei
  landet auch in den Test-Bundles, und `MeasurementData` müsste einen zweiten Ort kennen.
- C: Datei per `devicectl` in Documents der Labor-App legen. Kein Projektumbau, ist aber Gerätezugriff und gehört
  damit zu B2.

## Dependencies
- Upstream: `Corpus.entries`, `RawSentenceColumn`, `MeasurementStore`.
- Downstream: Laborlauf #88/#71 (ein gemeinsames Wort), `scripts/measurement_status.py`, `docs/reference/textform-rules.md`
  (Aufrufbeschreibung).

## Existing Specs
- `docs/specs/measurement/feat-88-echte-rohsaetze.md` (Schnitt A)

## Risks & Considerations
- Keine echten Sätze in Repo, Artefakten, Tickets, Berichten, nur Zählungen.
- Nichts auf Hennings Geräten, auch nichts Lesendes, vor seinem Wort. Der Export gehört zu B2.
- Laut scheitern muss auch Bundle ohne Datei (iPhone): der Läufer zeigt dann den Grund in der App.
- Scoping: 4–5 Dateien, ±250 LoC. Kein Pfad der Geräteliste berührt (Messcode; `project.yml` ist auf der Liste,
  falls Variante A gewählt wird: dann Stufe 3 beachten und in der Analyse sagen).
- #71 (andere Sitzung) ändert denselben Läufer (Schnitt 2a gemergt: `countRefusals`); vor dem Schnitt `origin/main`
  und offene PRs erneut prüfen.

## Analysis

### Type
Feature (Messwerkzeug, Schnitt B1 von #88). Kein Fehler im Produkt; Befund oben am Code bestätigt (2026-10-28, `origin/main` = HEAD, keine offenen PRs).

### Recherche (zuerst)
- XcodeGen: `optional: true` an einem Quelleintrag lässt `generate` auch ohne die Datei laufen; die Datei fehlt dann im Bau (Blogs: zenn.dev/dip_techblog „dip-2020-03-27-xcodegentips“, qiita.com/doi_daihei/items/594c15282e70c7d9235b). Amtliche Spec-Seite nicht in den Treffern: Verhalten wird in der Spec per lokalem `generate` mit und ohne Datei belegt.

### Ohne Modell
Kein Modell im Schnitt: reines Laden, Melden und Ablegen.

### Alternativen (Ablage)
| | Weg | Projektdatei | Gerät | Urteil |
|---|---|---|---|---|
| A | Datei bleibt in `docs/reference/`, Lab-Target bindet sie als optionale Ressource (`optional: true`) | `project.yml` | nein | **Empfehlung**: ein Ort, wie Schnitt A und `MeasurementData`; fehlt sie, bleibt das Bundle ohne sie und der Läufer sagt es |
| B | Export nach `Measurement/` (gitignoriert) | keine | nein | zwei Orte für dieselbe Datei; landet auch in beiden Test-Bündeln |
| C | per `devicectl` nach Documents der Labor-App | keine | **ja** | gehört zu B2, nicht vorbereitbar |
Gekippt würde keine ADR; „Messcode ohne Gerät“ bleibt.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Measurement/Corpus.swift` | MODIFY | `loadReport(fileName:)`: Einträge oder benannter Grund (Datei fehlt / unlesbar / leer); `load` bleibt |
| `LooseEndsLab/MeasurementRunner.swift` | MODIFY | `try?` ersetzen: Fehler als `loadProblem` ins Protokoll (`Logger` + Ereignis) und in den Zustand |
| `LooseEndsLab/LabApp.swift` | MODIFY | Grund als Zeile anzeigen, „Messen“ gesperrt |
| `project.yml` | MODIFY | Lab-Quelle `docs/reference/loose-ends-rawtexts.json`, `optional: true`, nur Lab |
| `LooseEndsTests/CorpusTests.swift` | MODIFY | Tests: fehlt → Grund; leer → Grund; kaputt → Grund; vorhanden → Einträge |
Schnitt B1b (eigener Workflow, nicht hier): `scripts/export-rawtexts.swift` (liest Store schreibgeschützt), Test gegen selbstgebaute Wegwerf-Datenbank, Aufrufbeschreibung in `docs/reference/textform-rules.md`.

### Scope Assessment
- Files: 5 (B1a), B1b 3 weitere. Zusammen 8 → über dem Limit, deshalb zwei Schnitte.
- Estimated LoC: +120/-10 (B1a)
- Risk Level: LOW (Messcode, nicht im Produktpfad). Einziger Fremdtreffer: `project.yml`.

### Technical Approach
1. `Corpus.loadReport` ist rein und testbar (der Läufer sitzt im Lab-Target, nicht in den Tests); der Läufer ruft nur sie auf.
2. Läufer: Problem sichtbar statt `idle`/„0 Sätze“; gilt für alle Korpora.
3. `project.yml` bindet die Datei nur ins Lab; ohne Datei (CI, andere Rechner) läuft `generate` weiter und der Läufer meldet „Korpus loose-ends-rawtexts fehlt im Bundle“.
4. Worktree-Falle: Die Datei liegt nur im Hauptordner. Ein Lab-Bau aus einem Worktree findet sie nicht. B1a lässt `sim.sh lab` die Datei vor `generate` aus dem Hauptordner verlinken, falls im Arbeitsstand keine liegt (gleiche Suche wie `MeasurementData.reference`); sonst meldet das der Läufer laut. Entscheidung für die Spec: Link in `sim.sh` (+1 Datei, ~10 LoC).

### Gerätestufe
`project.yml` steht auf der Geräteliste, also greift Stufe 3 formal. Sie fällt mit B2 zusammen (Laborlauf #88/#71, ein gemeinsames Wort). **Nichts auf Hennings Geräten vor seinem „jetzt ist ein Test möglich“.** Stufe 1 und 2 (Tests, Simulator-Bau der Lab-App ohne und mit Wegwerf-Datei) laufen ohne ihn.

### Dependencies
Upstream `Corpus.entries`, `RawSentenceColumn`; #71 ändert denselben Läufer (Schnitt 2a gemergt): vor dem Merge `origin/main` erneut prüfen.

### Open Questions
- [ ] Keine für Henning. Technisch entschieden: Variante A, Link in `sim.sh`, Aufteilung B1a/B1b.
