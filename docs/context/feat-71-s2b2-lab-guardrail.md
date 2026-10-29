# Context: feat-71-s2b2-lab-guardrail (#71, Schnitt 2b-2)

## Request Summary
Das Werkzeug für die iPhone-Spalte der Guardrail-Messung (Annahme B3): Korpusbau und Zählen als Skript, der Befehl
`sim.sh lab-guardrail` mit Trockenlauf, Selbsttest. Danach der Gerätedurchgang und der Datenschritt (Bericht, Rohdaten, B3).
Läufer (2a, PR #734) und Auswertung (2b-1, PR #735) stehen. Hintergrund und Risiken von Schnitt 2b insgesamt:
`docs/context/feat-71-guardrail-iphone-lauf.md` (dort Abschnitt „Vorlage für Schnitt 2b-2“ mit AC-8 bis AC-14 und Testentwurf)
und `docs/specs/spike-71-schnitt-2b-iphone-lauf.md`.

## Related Files
| File | Relevance |
|------|-----------|
| `scripts/sim.sh` | `cmd_lab_latency` / `lab_latency_launch` (Z. ~948–1005) als Vorlage; `cmd_lab_fetch` (Z. 895) holt per `devicectl device copy from`; `require_device`, `signed_build`, `device_derived_data`, `LAB_BUNDLE`; `cmd_real_model_guardrail` (Z. 456) als Vorbild für Quelle (`LOOSEENDS_FOCUSBLOX_CORPUS`), `$TMPDIR/loose-ends-71-guardrails/` und Rohdatenpfad; `cmd_sim_unit` (Z. 612) ruft `run_xcodebuild` ohne `TEST_RUNNER_`-Variablen, der Berichttest braucht sie also vom Aufrufer. |
| `scripts/gen_guardrail_corpus.py` | erzeugt `Measurement/guardrail-corpus.json` (100 heikle Texte); Form der Einträge `id`, `lang`, `text`, `form`. |
| `Measurement/guardrail-corpus.json` | Quelle der heiklen Menge (`gr-001` …), unverändert zu übernehmen. |
| `Measurement/Corpus.swift` | `exitWhenDone` (Z. 239), `countRefusals` (Z. 245, `--count-failures`), `Corpus.url` findet `Documents/`. |
| `Measurement/GuardrailReport.swift` | `GuardrailProbe.probes(from:corpus:runsPerEntry:)`, `withoutEverydayWording` (2b-1). |
| `LooseEndsTests/GuardrailReportTests.swift` | `IphoneGuardrailReportTests` (Z. ~330): läuft nur mit `LOOSEENDS_GUARDRAIL_IPHONE_RESULT` und `LOOSEENDS_GUARDRAIL_CORPUS`; schreibt Rohdaten nach `LOOSEENDS_GUARDRAIL_OUT`, Zusammenfassung nach `LOOSEENDS_GUARDRAIL_LOCAL`. |
| `scripts/latency_summary.py`, `scripts/test_latency_summary.py` | Muster für Hilfsskript mit Selbsttest. |
| `/Users/hem/Developer/loose-ends/docs/reference/focusblox-corpus.json` | 287 persönliche Sätze, gitignored, nur im Hauptordner. |

## Existing Patterns
- Hilfsskripte liegen in `scripts/` mit `test_<name>.py` daneben (Python, `-I`-tauglich, keine Fremdpakete).
- Gerätebefehle: erst Meldung, dann `require_device`; Labor-App nur unter `$LAB_BUNDLE`, die Kennung wird nach dem Bau aus der `Info.plist` geprüft.
- Läufer schreibt nach jedem Satz und setzt beim nächsten Start fort (Scheibenbetrieb); der Ergebnisname ist neu (`guardrail-iphone`), daher keine Deinstallation nötig.
- Berichttest als Suite mit `.enabled(if:)`, damit er im normalen Lauf nicht mit Nullen entwertet.

## Dependencies
- Upstream: 2a, 2b-1, `devicectl`, Labor-App (`LooseEndsLab`), FocusBlox-Korpus im Hauptordner.
- Downstream: B3-Entscheidung (Epic #370), #176 (wartet auf #71 und #88), mögliches Folgeticket „Modell hat abgelehnt“ bei über 1 %.

## Befunde beim Lesen (für die Spec)
1. `devicectl device copy to` kommt in `sim.sh` noch nicht vor, nur `copy from`. Die Korpusdatei muss per `copy to` nach `Documents/guardrail-geraet.json` im Container der Labor-App; der Aufruf ist im Trockenlauf nicht belegbar und muss in der Spec als Gerätepunkt stehen. Recherche zur genauen Syntax (`--domain-type appDataContainer --domain-identifier … --destination`) steht in Analyse.
2. `cmd_sim_unit` reicht keine Umgebungsvariablen durch. Der Berichttest in Schritt 6 braucht `TEST_RUNNER_LOOSEENDS_GUARDRAIL_*`, die der Befehl selbst vor dem Aufruf setzt (wie `cmd_real_model_guardrail`).
3. Der Berichttest hängt an `#if canImport(FoundationModels)`; im Simulator ist das übersetzbar, aber das Modell ist nicht nötig, weil er nur eine Datei liest. Zu belegen im Simulator-Durchlauf mit einer erfundenen Ergebnisdatei.
4. Datenschutz (N1/N2 aus dem Prüfdialog 2b-1): `build` erzwingt eindeutige Ids und die Präfixe `gr-` oder `alltag-`, sonst Abbruch vor dem Schreiben; das Ziel liegt nie im Repo.
5. Umfang: `sim.sh` (ca. +90), `scripts/guardrail_corpus.py` (ca. +60), `scripts/test_guardrail_corpus.py` (ca. +120) sind 3 Dateien, zusammen etwas über der Schätzung 175 LoC, aber innerhalb ±250; Bericht und Rohdaten zählen als Daten des Datenschritts.

## Risks & Considerations
- **Gerät nur auf Hennings Wort.** Die Freigabe vom 2026-10-28 war für einen Durchgang, der noch nicht stattfand; sie ersetzt aber keine neue Frage. Vor dem Lauf per Auswahl fragen (Dauer etwa 62 Minuten reine Modellzeit, Obergrenze 25 s je Aufruf), mit dem Start in derselben Nachricht rufen; vorher gebaut, im Simulator belegt, Trockenlauf ohne Fehler.
- Persönliche Sätze nie im Repo, nie im Bündel, nie in Rohdaten oder Berichtstexten.
- Gesperrtes iPhone beendet den Befehl sauber mit Hinweis, der Stand bleibt auf dem Gerät.
- Geräteliste: kein Produktpfad berührt; der Lauf ist selbst der Gerätedurchgang.

## Analysis
Typ: Feature (Spike, Werkzeug und Messung). Ohne Modell geht es nicht, weil die Frage lautet, ob das Modell ablehnt; Regel-Spalte 0 % per Konstruktion. Alternative: B3 allein auf der Mac-Zahl (0,52 %, obere Grenze 1,86 %) entscheiden und den iPhone-Lauf streichen; dagegen spricht die neuere Modellgeneration auf dem iPhone. Keine ADR berührt.

### Recherche zu Befund 1 (2026-10-29)
`xcrun devicectl device copy to --help` (lokal, Xcode 27) und Apple-Forum „Copy app files using devicectl“ (https://developer.apple.com/forums/thread/765386):
`devicectl device copy to --device <id> --user mobile --domain-type appDataContainer --domain-identifier <Bundle-ID> --source <Datei> --destination Documents/<Datei>`.
Die Kennung ist die Bundle-ID, `Documents/` gehört in `--destination`, nicht in die Kennung; `--user mobile` wie in `cmd_lab_fetch` (Z. 900). `copy to` überspringt unveränderte Dateien. Ob die Datei tatsächlich im Container landet, zeigt nur der Gerätedurchgang.

### Alternative zum Werkzeug (Entscheidung offen für die Spec)
Korpus als Bündelressource der Labor-App statt `copy to`: kein Gerätezugriff für den Transfer nötig, aber persönliche Sätze lägen im Bau. Verworfen wegen N2 (Datenschutz); `copy to` bleibt der Weg.

### Scope / Risiko
Dateien: `scripts/sim.sh`, `scripts/guardrail_corpus.py`, `scripts/test_guardrail_corpus.py` (3). Geschätzt +270 LoC, am oberen Rand von ±250; Spec trennt Werkzeug (Schnitt 2b-2a) und Gerätedurchgang mit Datenschritt (2b-2b), falls die Zählung über 250 liegt. Risiko: Mittel, weil der Gerätedurchgang nur auf Hennings Wort läuft.
