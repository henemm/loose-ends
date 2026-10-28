# Context: feat-71-guardrail-iphone-lauf (#71, Schnitt 2b)

## Request Summary
Schnitt 2b von #71 (Annahme B3): Die iPhone-Spalte wirklich messen. 2a (PR #734) hat den Läufer fertig gemacht
(`--count-failures`, Korpus aus `Documents/`). Jetzt fehlen: das Skript `sim.sh lab-guardrail`, die Übersetzung
Läufer-Ergebnis → `GuardrailProbe`, die iPhone-Spalte im Bericht `docs/reference/modell-guardrails.md` und die Rohdaten
`docs/artifacts/71-guardrails/iphone-rohdaten.json`. Henning hat am 2026-10-28 wörtlich „jetzt ist ein Test möglich“
geschrieben: Das gilt für **diesen einen Durchgang** (Gerät lesen, Labor-App installieren, messen, Dateien holen). Die
Hintergründe, Risiken und die Alternative stehen in `docs/context/feat-71-guardrail-iphone-spalte.md` und
`docs/context/spike-71-guardrail-rate.md` und gelten unverändert.

## Related Files
| File | Relevance |
|------|-----------|
| `Measurement/GuardrailReport.swift` | `GuardrailProbe` und die Zählung mit Wilson-Grenze. Hier kommt die Übersetzung `MeasurementResult` → `GuardrailProbe` hinein (`entryID`, `runIndex`, `errorKind`; Menge/Gruppe/Sprache aus dem Korpuseintrag). |
| `Measurement/MeasurementRun.swift` | `MeasurementResult`, `wasRefused`, `countsAsMeasured` (2a). Ein Ergebnis mit `errorKind` guardrail/refusal ist eine Ablehnung, alles andere mit Fehler wird ausgenommen. |
| `Measurement/Corpus.swift` | Format der Einträge (`id`, `lang`, `text`, `form`); `Corpus.url` findet seit 2a Dateien in `Documents/`. |
| `Measurement/guardrail-corpus.json` | 100 heikle Texte (`gr-001` …), im Bündel der Labor-App. |
| `LooseEndsTests/RealModelGuardrailTests.swift` | Mac-Weg als Vorbild: Mengen `heikel` + `alltag` (Id `alltag-<Index>`, nie der Satz), Rohdatei ohne Alltagswortlaut, lokale Auswertung mit Wortlaut nur außerhalb des Repos. Der Kopf der Rohdatei (`Head`, `RawFile`) ist dort definiert. |
| `LooseEndsTests/GuardrailReportTests.swift` | Muster für Unit-Tests der Zählung. |
| `scripts/sim.sh` | `lab_latency_launch` / `cmd_lab_latency` (Zeilen ~948–1005) sind die Vorlage: Start per `devicectl … --measure --corpus … --runs 2 --result … --exit-when-done`, Datei per `devicectl device copy from` zurück. Dazu `require_device`, `signed_build`, `LAB_BUNDLE`, `cmd_lab_fetch`. |
| `docs/reference/modell-guardrails.md`, `docs/artifacts/71-guardrails/` | Bericht mit Mac-Spalte; Rohdaten Mac. |
| `/Users/hem/Developer/loose-ends/docs/reference/focusblox-corpus.json` | Die 287 persönlichen Sätze (`lang`, `rawText`), gitignored, nur im Hauptordner. Quelle für die Alltagsmenge; nie ins Repo, nie ins Bündel. |

## Existing Patterns
- Die Alltagsmenge wird auf dem Rechner zu einer Korpusdatei (`alltag-<Index>`, `form` = `alltag`) zusammen mit den 100 heiklen
  Texten gebaut, **außerhalb des Repos** abgelegt und per `devicectl device copy to` in `Documents/` der Labor-App gelegt.
  Sie verschwindet mit der Deinstallation der Labor-App.
- Rohdaten tragen für die Alltagsmenge nie den Wortlaut (`text = nil`); eine lokale Zusammenfassung mit Wortlaut der Treffer
  liegt nur außerhalb des Repos.
- Läufer schreibt nach jedem Satz und macht beim nächsten Start weiter; so läuft die Messung in Scheiben, ohne dass Henning
  das iPhone dauernd bereithalten muss (Memory: Handy ist kein Prüfstand).
- Messberichte-Tests (Memory „Messberichte zerstören sich“): ein Berichtstest läuft nur mit gesetzter Umgebungsvariable,
  sonst entwertet der Simulator den Bericht mit Nullen.

## Dependencies
- Upstream: 2a (gemergt), `GuardrailReport` (Schnitt 1), `MeasurementErrorKind.classify` (#536), Labor-App (`LooseEndsLab`).
- Downstream: Entscheidung über B3 (Epic #370, externe Tester), #176 (wartet auf #71 und #88). Bei Überschreitung der
  1-%-Schwelle ein Folgeticket „Modell hat abgelehnt“ als sichtbarer Zustand (Alternativen im Ticket).

## Existing Specs
- `docs/specs/spike-71-schnitt-2a-laeufer-ablehnung.md` (2a, gemergt). Muster für Gerätelauf-Spikes: #534 Schnitt 2.

## Risks & Considerations
1. **Gerät nur auf Hennings Wort.** Das Wort liegt vor (2026-10-28) für diesen einen Durchgang. Er darf erst beginnen, wenn
   Skript, Übersetzung und Tests fertig und im Simulator belegt sind („Bereit, bevor ich Henning rufe“). Reihenfolge dagegen:
   erst bauen, dann messen.
2. **Das iPhone muss entsperrt und im selben WLAN sein**, sonst bricht `devicectl` ab. Henning wird mit dem Start gerufen,
   nicht vorher.
3. **Dauer.** 387 Texte × 2 Durchläufe = 774 Aufrufe; auf dem iPhone 25 s Obergrenze je Aufruf (Latenz #534). Realistisch
   deutlich unter einer Stunde, in Scheiben möglich. Das Skript meldet vorher Zahl und Dauer.
4. **Persönliche Sätze.** Weder im Repo noch im Bündel, weder in Rohdaten noch in Berichtstexten (nur `alltag-<Index>`);
   Treffer mit Wortlaut nur lokal außerhalb des Repos.
5. **Umfang.** Limit 4–5 Dateien, ±250 LoC: Übersetzung (`GuardrailReport.swift`), Tests, `sim.sh`, ein kleines Hilfsskript
   für Korpus und Rohdaten, dazu Bericht und Rohdaten (Doku/Daten). Wird es knapp, ist der Bericht der Teil, der in einen
   eigenen Durchgang darf.
6. **Geräteliste.** Berührt kein Produktpfad der Liste; die Messung auf dem iPhone ist der Gerätelauf selbst.

## Analysis
Typ: Feature (Spike, Messung). Ohne Modell geht es nicht, weil die Frage lautet, ob das Modell ablehnt; die Regel-Spalte
ist 0 % per Konstruktion (Regeln lehnen nie ab). Alternative: B3 allein auf der Mac-Zahl (0,52 %, obere Grenze 1,86 %)
entscheiden; würde die Trennung nach Modellgeneration kippen und lässt die Frage offen, ob die Schwelle auf dem iPhone hält.

## Vorlage für Schnitt 2b-2 (aus der geteilten Spec, Stand 2026-10-28)

Schnitt 2b wurde geteilt (Limits 5 Dateien / ±250 LoC): 2b-1 = Übersetzung + Berichttest (Swift), 2b-2 = Werkzeug
(`sim.sh lab-guardrail`, `scripts/guardrail_corpus.py`, `scripts/test_guardrail_corpus.py`) + Gerätelauf + Datenschritt.
Entwurf, Akzeptanzkriterien und Tests von 2b-2:

### 3. Gerätekorpus (`scripts/guardrail_corpus.py`)

- `build <focusblox.json> <ziel.json>`: liest `Measurement/guardrail-corpus.json` (100 Einträge, bleiben unverändert mit `id`, `lang`, `text`, `form`) und die FocusBlox-Datei (`lang`, `rawText`); Alltag: `id` = `alltag-<Index>` (Index = Position in der FocusBlox-Datei, ab 0, wie am Mac), `text` = `rawText`, `form` = `alltag`. Schreibt nur nach `<ziel.json>`; bricht mit Fehlermeldung ab, wenn der aufgelöste Zielpfad im Repo liegt (Wurzel per `git rev-parse --show-toplevel` des Skripts) oder wenn die Zahl der heiklen Einträge ≠ 100 ist. Meldet am Ende die Zahlen (100 + N), nie einen Satz.
- `count <ergebnis.json>`: gibt die Zahl der Ergebnisse aus, die als gemessen zählen (`error` leer, oder `errorKind` ist `guardrail` oder `refusal`; gleiche Regel wie `countsAsMeasured(countRefusals: true)`), je Eintrag × Durchlauf einmal gezählt, auch wenn die Datei nach einer Wiederholung mehr Ergebnisse als Aufrufe enthält. So endet die Schleife nicht an einer Ergebniszahl, die Ausnahmen mitzählt.

### 4. Befehl `lab-guardrail` (`scripts/sim.sh`)

Kopfkommentar wie bei `lab-latency`: nur nach Hennings wörtlichem „jetzt ist ein Test möglich“, fasst nur die Labor-App (`LAB_BUNDLE`) an. Ablauf von `cmd_lab_guardrail`:

1. Korpus mit `guardrail_corpus.py build` nach `${TMPDIR:-/tmp}/loose-ends-71-guardrails/guardrail-geraet.json` bauen (Quelle: `LOOSEENDS_FOCUSBLOX_CORPUS` oder der Hauptordner-Pfad wie bei `real-model-guardrail`).
2. **Meldung vor allem Gerätezugriff:** Zahl der Aufrufe (387 Texte × 2 = 774), geschätzte Dauer (Median warm 4,83 s je Aufruf nach `docs/reference/modell-latenz.md` ergibt ca. 62 Minuten reine Modellzeit; Obergrenze 25 s je Aufruf), Hinweis „iPhone entsperrt lassen, im selben WLAN“. Mit `--dry-run` endet der Befehl hier (Trockenlauf ohne Gerät, belegbar im Simulator-Durchgang).
3. `require_device`, `ensure_project`, `signed_build` der Labor-App, Prüfung der Kennung wie in `cmd_lab_latency`. **Keine Deinstallation**; der Ergebnisname `guardrail-iphone` ist neu, der Läufer setzt sonst fort (das ist erwünscht, Scheibenbetrieb).
4. Korpusdatei per `devicectl device copy to` nach `Documents/guardrail-geraet.json` im Container der Labor-App.
5. Scheibe: Start mit `--measure --corpus guardrail-geraet --runs 2 --result guardrail-iphone --count-failures --exit-when-done --context-words Computer,Telefon,Haus,Garten,Unterwegs,Besorgung`, mit `timeout`; Ergebnisdatei zurückholen, `guardrail_corpus.py count` prüfen. Schleife, bis 774 gemessen sind oder die Höchstzahl der Scheiben erreicht ist (Abbruch mit Meldung, Stand bleibt auf dem Gerät und in der geholten Datei, ein erneuter Aufruf setzt fort). Gesperrtes Gerät (`Locked`) beendet sauber mit Hinweis.
6. Ergebnisdatei in das Scratch-Verzeichnis außerhalb des Repos holen und den Berichttest im Simulator mit gesetzten Variablen (`TEST_RUNNER_…`) laufen lassen: Rohdaten nach `docs/artifacts/71-guardrails/iphone-rohdaten.json`, lokale Zusammenfassung nach `${TMPDIR:-/tmp}/loose-ends-71-guardrails/iphone-auswertung.txt`.

Keine Befehle, die eine `$`-Variable als Programm ausführen; Fehler werden gemeldet, nicht verschluckt.


- **AC-8:** `scripts/guardrail_corpus.py build` erzeugt aus einer erfundenen FocusBlox-Datei und `Measurement/guardrail-corpus.json` eine Datei mit 100 + N Einträgen, Alltag mit `id` `alltag-<Index>` und `form` `alltag`; sie ist über `Corpus.entries(from:)` lesbar (Eintragsformat `id`, `lang`, `text`, `form`). Liegt der Zielpfad im Repo, bricht das Skript mit Fehlerstatus ab und schreibt nichts; bei ≠ 100 heiklen Einträgen ebenfalls. Es gibt keinen Satz auf der Standardausgabe aus.
- **AC-9:** `scripts/guardrail_corpus.py count` zählt je Eintrag × Durchlauf höchstens einmal und nur Erfolge, `guardrail` und `refusal`; `rateLimited` und `timeout` zählen nicht; doppelte Ergebnisse desselben Eintrags und Durchlaufs zählen einmal. Selbsttest `scripts/test_guardrail_corpus.py` grün.
- **AC-10:** `./scripts/sim.sh lab-guardrail --dry-run` baut die Korpusdatei außerhalb des Repos, gibt Aufrufzahl (774), geschätzte Dauer und „iPhone entsperrt lassen“ aus und endet mit Status 0, **ohne** `require_device`, `devicectl`-Aufruf oder Build aufzurufen. `bash -n scripts/sim.sh` meldet keinen Fehler.
- **AC-11:** Statische Prüfung in `scripts/test_guardrail_corpus.py` über den Text von `cmd_lab_guardrail`: enthält weder `device uninstall` noch eine andere Kennung als `$LAB_BUNDLE`, enthält die Argumente `--count-failures`, `--runs 2`, `--result guardrail-iphone`, `--exit-when-done`, schreibt Rohdaten nur nach `docs/artifacts/71-guardrails/` und die lokale Zusammenfassung nur unter `${TMPDIR`, und ruft `require_device` erst nach der Meldung (Zahl, Dauer) auf.
- **AC-13 (Datenschritt nach dem gemessenen Lauf):** `docs/reference/modell-guardrails.md` hat eine iPhone-Spalte neben der Mac-Spalte; ihre Zahlen (Texte, Treffer, Rate, Wilson-Grenze, ausgenommene Proben, Gerät, System, Datum) sind wörtlich die Ausgabe des Berichttests aus der geholten Datei; die Regel-Spalte steht mit 0 % und dem Satz „Ohne Modell geht es nicht, weil …“ da; die Entscheidung zu B3 nennt die Zahl und die 1-%-Schwelle.
- **AC-14 (Datenschritt):** `docs/artifacts/71-guardrails/iphone-rohdaten.json` enthält 774 Proben, `proben[].text` ist für jede Probe der Menge `alltag` nicht gesetzt, Ids der Alltagsmenge haben die Form `alltag-<Index>`. Ein Test mit `grep` belegt, dass kein Wort aus der lokalen Zusammenfassung (Wortlaut der Treffer) im Repo steht.

- Test: GIVEN eine erfundene FocusBlox-Datei mit 3 Sätzen WHEN `build` THEN 103 Einträge, `alltag-0` bis `alltag-2`, `form` `alltag`, über `Corpus.entries(from:)` lesbar (AC-8, Python plus Swift-Lesetest oder JSON-Schemaprüfung)
- Test: GIVEN ein Zielpfad im Repo WHEN `build` THEN Fehlerstatus, Datei nicht angelegt (AC-8)
- Test: GIVEN Ergebnisse mit Erfolg, `refusal`, `rateLimited`, einem Doppel WHEN `count` THEN nur Erfolg und `refusal`, Doppel einmal (AC-9)
- Test: GIVEN `lab-guardrail --dry-run` WHEN ausgeführt (mit gesetzter Quelle auf erfundene Datei) THEN Status 0, Ausgabe enthält 774 und „entsperrt“, kein `devicectl` im Prozess (AC-10, Skript-Selbsttest mit Attrappe `DEVICECTL`)
## Aus dem Prüfdialog von 2b-1 (für 2b-2 einzuarbeiten)

- N1: `GuardrailProbe.probes` prüft keine doppelten Ids im Korpus; bei Doppel teilen sich beide Einträge ein Ergebnis, `missing` bleibt 0. Der Korpusbau (`build`) muss eindeutige Ids erzwingen.
- N2 (Datenschutz): Jede Id ohne Präfix `alltag-` gilt als `heikel`, ihr Text bleibt in den Rohdaten. Der Korpusbau erzwingt daher das Präfix (`gr-` oder `alltag-`) und bricht bei jeder anderen Id ab, bevor ein persönlicher Satz in Rohdaten gelangen kann; der Berichttest bricht ebenso ab.
