# Context: fix-419-latenzschutz

## Request Summary
#419 (Epic #465): Der Latenzschutz aus #274 (zwei Messtests in `SpeechLatencyTests`) läuft nirgends. Er soll bei jedem
CI-Lauf mit echtem Ergebnis laufen, oder sein Ausfall muss laut sichtbar sein wie bei den Messstrecken (#149).

**Hat es bisher funktioniert?** Nein, nie. Die Tests wurden mit #274 (2026-10-09) gebaut und liefen nur auf Hennings Mac
von Hand. Kein Rückschritt, die Historie grenzt nichts ein.

## Befund (am 2026-10-19 selbst nachgestellt, nicht aus dem Ticket übernommen)
- CI-Lauf 39167072947 (main, 20b9553), Job „Unit Tests (macOS destination)“, Artefakt `TestResults`, `unit-tests.log` Z. 5249-5252:
  beide Messtests „was cancelled after 0.003 seconds: „Sprache de_DE wird hier nicht unterstützt““.
- Das ist der erste Wächter in `SpeechLatencyTests.measuredRun()`: `SpeechTranscriber.supportedLocale(equivalentTo: de_DE)`
  liefert `nil`. Es fehlt also nicht (nur) das Sprachmodell (der Modellstatus-Wächter kommt erst danach); die Sprachliste
  des Rechners ist leer oder enthält Deutsch nicht.
- Im Job-Log (xcbeautify) stehen die zwei Tests gar nicht, nur der dritte (Konstantentest). Im Rohlog stehen sie als „cancelled“.
- Die Zusammenfassung der CI (`scripts/measurement_status.py --markdown`) kennt nur Suiten, die an Dateien hängen
  (`GATES`); ein per `Test.cancel` übersprungener Test erscheint dort nicht.

## Recherche (Quellen)
- Apple-Forum 802969 „SpeechTranscriber on Simulator“: `supportedLocales` leer, `isAvailable == false` im Simulator
  (Xcode 26.0/26.1); keine Antwort von Apple. https://developer.apple.com/forums/thread/802969
- Apple-Forum 807739 / 801197: Verfügbarkeit hängt an der Hardware (Neural Engine). https://developer.apple.com/forums/thread/807739
- GitHub-Läufer sind selbst virtuelle Maschinen (keine verschachtelte Virtualisierung, runner-images #9460).
  **Vermutung, nicht belegt:** dasselbe Muster wie im Simulator. Belegt wird sie nur durch einen Diagnoselauf im CI.
- `DictationTranscriber` (SFSpeechRecognizer-Modelle) ist die dokumentierte Alternative für Rechner ohne `SpeechTranscriber`;
  er misst aber nicht den Pfad der App (die App nutzt `SpeechTranscriber` mit `.fastResults`).

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEndsTests/SpeechLatencyTests.swift` | Die zwei Messtests; `measuredRun()` bricht mit `Test.cancel` ab (Sprache, dann Modellstatus) |
| `LooseEnds/Speech/SpeechCapture.swift` | `transcriberReportingOptions`, `makeTranscriber(locale:)` (nicht ändern) |
| `.github/workflows/ci.yml` (Job `unit-macos`, Z. ~40-100) | Testlauf, Rohlog als Artefakt, Schritt „Report skipped measurements“ |
| `scripts/measurement_status.py`, `scripts/test_measurement_status.py` | Zusammenfassung „Messstrecken“; Vorbild für eine Zeile „Latenzschutz“ |
| `scripts/sim.sh` (`measurement_status`, Z. 272-294, 424) | Ruft das Skript nach `unit`/`sim-unit` |
| `.github/workflows/speech-stress.yml` | Läuft im iOS-Simulator (laut Recherche dort ebenfalls ohne `SpeechTranscriber`), also kein Ausweg |
| `docs/context/279a-sprachstart-latenz.md`, `docs/artifacts/fix-274-spracheingabe-latenz/` | Vorgeschichte, Mac-Versuchsaufbau |

## Existing Patterns
- #149: Wer nicht misst, sagt es laut: Zeile in `sim.sh` und `GITHUB_STEP_SUMMARY`, erzeugt von einem getesteten Python-Skript.
- Übersprungene Tests werden nie als Gesamtzahl gemeldet, sondern einzeln benannt (Memory „Übersprungene Tests einzeln benennen“).

## Dependencies / Dependents
- Upstream: Apple Speech (`SpeechTranscriber`, `AssetInventory`), Testbundle-Fixture `speech-de.m4a`.
- Downstream: nur CI und `sim.sh`-Ausgabe; die App bleibt unverändert (kein Gerätepfad der Stufe-3-Liste berührt).

## Entscheidungspunkt für die Analyse
- **Weg A** (Diagnoselauf zeigt: geht im CI): Messtests laufen echt, ggf. Modell per `AssetInventory` nachladen.
- **Weg B** (geht im CI nicht): Ausfall laut sichtbar machen (eigene Zeile „Latenzschutz: 2 von 2 nicht gemessen, Grund …“
  in Zusammenfassung, Annotation und `sim.sh`). Gegenprobe der DoD („ohne `.fastResults` rot“) ist dann im CI nicht erfüllbar
  und wird in der Spec offen benannt; sie läuft ersatzweise als Skripttest über das Rohlog.
- **Alternative zu beidem:** eigener Mac mit echter Hardware als Läufer (Aufwand, braucht Freigabe von Henning). Würde ADR-
  Entscheidung „CI auf GitHub-Läufern“ kippen.
- Zuerst die einfachste Regel: Das Rohlog sagt eindeutig „cancelled“; ein Regelwerk über das Log (kein Modell, keine Erweiterung der App) genügt für Weg B.

## Risks
- Der Diagnoselauf braucht einen CI-Durchlauf auf einem Wegwerf-Zweig (Minuten, keine Gerätezugriffe).
- Scoping: CI-Datei + Skript + Skripttest + (ggf.) Testdatei, voraussichtlich ≤ 4 Dateien, < 100 LoC.

## Analysis

### Type
Bug (Schutz existiert, läuft aber nie; „Hat es bisher funktioniert?“ — nein, nie seit #274).

### Without the model / Regelweg
Kein Modell im Spiel. Der Ausfall ist deterministisch im Rohlog erkennbar („was cancelled … Sprache de_DE wird hier nicht unterstützt“).
Regelweg: Skript liest das Rohlog (CI) bzw. xcresult (sim.sh) und benennt die zwei Tests einzeln als „nicht gemessen“.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/measurement_status.py` | MODIFY | Zeile „Latenzschutz (#274)“: je Messtest gemessen / nicht gemessen + Grund, aus dem Testlog |
| `scripts/test_measurement_status.py` | MODIFY | Skripttests: cancelled → laut benannt, bestanden → mit Zeit, Test fehlt im Log → ebenfalls laut |
| `.github/workflows/ci.yml` | MODIFY | Schritt „Report skipped measurements“ übergibt `unit-tests.log`; Annotation `::warning::` bei Ausfall; ggf. Diagnoseschritt |
| `scripts/sim.sh` | MODIFY (klein) | `measurement_status` bekommt das Log/xcresult des Laufs |
| `LooseEndsTests/SpeechLatencyTests.swift` | ggf. MODIFY | Nur bei Weg A (Modell nachladen); sonst unverändert |

### Scope Assessment
- Files: 4–5, Estimated LoC: +90/−10, Risk: LOW (kein App-Code, kein Pfad der Geräteliste)

### Technical Approach
Zweistufig, Diagnose zuerst (Reproduktion/Recherche-Regel):
1. **Diagnoselauf im CI** (Wegwerf-Zweig, kein Gerät): gibt `SpeechTranscriber.isAvailable`, `supportedLocales`, `installedLocales` aus.
   Recherche (Apple-Forum 802969, 807739): im Simulator/auf virtualisierter Hardware sind die Listen leer — Vermutung für GitHub-Läufer, erst der Lauf belegt es.
2. **Weg A** (Liste enthält de_DE): Modell per `AssetInventory.assetInstallationRequest` vor dem Test laden; Tests laufen echt.
   **Weg B** (Liste leer, wahrscheinlich): Ausfall laut sichtbar (Zusammenfassung, Annotation, sim.sh). Die Gegenprobe der DoD
   („ohne `.fastResults` rot“) ist im CI dann nicht erfüllbar; Ersatz: Skripttest über ein Log mit langsamer Erkennung, plus ehrliche Benennung in der Spec.

### Alternativen (bewusst genannt)
- Eigener Mac mit echter Hardware als Läufer (Tests laufen wirklich, Aufwand + Freigabe von Henning; kippt die Entscheidung „CI nur auf GitHub-Läufern“).
- Tests auf `DictationTranscriber` umstellen: läuft evtl. überall, misst aber nicht den App-Pfad (`SpeechTranscriber` + `.fastResults`) — schwächerer Schutz.
- Verlegen in „Speech Stress“: laut Recherche gleiche Simulator-Lücke, kein Ausweg.

### Dependencies
Apple Speech, Fixture `speech-de.m4a`, `measurement_status.py` (Vorbild #149), `sim.sh` Z. 270–294.

### Open Questions
- [ ] Liefert der GitHub-Läufer `supportedLocales` für de_DE? (Diagnoselauf entscheidet A/B; kein Henning-Input nötig)
