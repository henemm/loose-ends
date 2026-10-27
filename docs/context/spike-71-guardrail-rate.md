# Context: spike-71-guardrail-rate (#71)

## Request Summary
Spike #71 (Epic #370, M3, Annahme B3): Lassen die Guardrails des On-Device-Modells Alltagstext durch? Gemessen wird die
Verweigerungsrate auf dem FocusBlox-Korpus plus 100 heiklen Alltagstexten, Mac und iPhone getrennt, Guardrail-Fehler und
Rate-Limit-Fehler getrennt gezählt. Abbruchkriterium: über 1 % auf Alltagstext. Die Messung auf dem iPhone braucht
Hennings wörtliches „jetzt ist ein Test möglich“; sie wird mit #88 Teil 2 gebündelt.

## Related Files
| File | Relevance |
|------|-----------|
| `Measurement/guardrail-corpus.json` | 100 Texte (PR #276): 10 Gruppen à 10, 90 DE und 10 EN. Felder `id`, `lang`, `text`, `form` (hier die Themengruppe, nicht die Satzform). |
| `LooseEndsTests/GuardrailCorpusTests.swift` | Prüft nur den Aufbau des Korpus (100 eindeutig, zehn Gruppen, DE/EN). Keine Auswertung. |
| `Measurement/MeasurementRun.swift` | `MeasurementResult` mit `errorKind`, `wasRateLimited`; `MeasurementErrorKind.classify` unterscheidet `guardrail`, `refusal`, `rateLimited`, `contextWindow`, `timeout`, `other`; `MeasurementRun.rateLimitedAttempts`. Es gibt keine Auswertung je Fehlerart, Gruppe, Sprache. |
| `LooseEndsLab/MeasurementRunner.swift` | Läufer: ein Satz je Aufruf, Datei nach jedem Satz. Wiederholt nach Fehlschlag (60 s Pause, nach 3 Fehlern in Folge Stopp). Das passt schlecht zu einer Verweigerungsmessung, denn ein Guardrail-Treffer ist dauerhaft und würde bei jedem Lauf wieder versucht (`remaining` zählt nur Erfolge). |
| `Shared/Enrichment/ModelFailure.swift` | `isPermanent`: Guardrail und Kontextfenster gelten im Produkt als dauerhaft (#535). |
| `Shared/Enrichment/FoundationModelsEnricher.swift` | Der gemessene Aufruf; `unavailableReason`. |
| `LooseEndsTests/RealModelLatencyTests.swift`, `RealModelGateTests.swift` | Muster für einen Modelltest auf dem Mac (`LOOSEENDS_REAL_MODEL=1`, nie in der CI, Rohdaten nach JSON per Umgebungsvariable). |
| `scripts/sim.sh` (`real-model-latency`, `lab-latency`, `lab_latency_launch`) | Bestehende Wege für Mac und iPhone; `lab-latency` deinstalliert die Labor-App vorher und holt Dateien per devicectl. Läuft auf dem iPhone nur nach Hennings Wort. |
| `scripts/latency_summary.py` (+ Test) | Muster für ein Auswertungsskript (liest Mac- und Labor-Format). |
| `docs/reference/modell-latenz.md` | Muster für den Bericht (Messaufbau, Ergebnis, Entscheidung). |
| `docs/project/06-annahmen-und-experimente.md` (B3) | Annahme, Messgröße, Abbruchkriterium und Alternativen. |
| `docs/reference/focusblox-corpus.json` | 287 echte Aufgaben (`text`, `rawText`, `lang`, …). Persönliche Daten, **gitignored**: liegt nur im Hauptordner `/Users/hem/Developer/loose-ends/docs/reference/`, nicht im Worktree und nicht in der CI. |

## Existing Patterns
- Modellmessungen laufen in der Labor-App (`com.henning.looseends.lab`) mit `--corpus <name> --result <name>`; Rohdaten unter
  `docs/artifacts/<ticket>/`, Bericht unter `docs/reference/`.
- Auf dem Mac läuft das echte Modell als Swift-Testing-Suite mit Umgebungsvariable, ohne Labor-App; der Test schreibt Rohproben als JSON.
- Berichte führen die Nulllinie (Regeln vor Modell). Für diese Messung hat die Regel-Spalte keinen Inhalt: Regeln verweigern nie.
  Die Alternative bei Überschreitung ist der Regelweg („Parser ohne Modell für diese Aufgabe“).

## Dependencies
- Upstream: #276 (Korpus, gemergt), #535 (Dauerfehler / `ModelFailure`), #536 (typisierte Fehler seit dem iOS-27-SDK), #68 (Modellverfügbarkeit je Gerät, erledigt).
- Downstream: Annahme B3 und Epic #370 (Tor für die Einladung externer Tester); bei Überschreitung ein Folgeticket für den sichtbaren Zustand
  „Modell hat abgelehnt“ statt stummem „ungeprüft“.
- Gebündelt mit: #88 Teil 2 (Laborlauf auf dem iPhone, Hennings echte Rohsätze).

## Existing Specs
- `docs/specs/` enthält Muster, aber keine Spec zu #71. Nächstes Muster für einen Spike: `docs/specs/` zu #70 / #534.

## Risks & Considerations
1. **FocusBlox-Korpus ist nicht im Worktree und nicht in der CI.** Er ist gitignored und lag bisher nur im Hauptordner. Ein Lauf „komplett“ braucht eine Kopie
   im Bündel der Labor-App oder einen Weg, ihn zu laden, ohne persönliche Texte einzuchecken.
2. **Läufer wiederholt Guardrail-Treffer.** Für diese Messung zählt jeder Satz einmal, auch bei Fehlschlag. Sonst läuft ein dauerhaft abgelehnter Satz in Schleife und
   der Dreifehler-Stopp bricht den Lauf mitten im Korpus ab. Das ist eine Änderung am Läufer, die B3 braucht und die `#88` nicht stört, wenn sie nur mit eigenem Schalter gilt.
3. **„Rate-Limit“ ist irreführend** (laut Ticket): die Meldung kann Last oder Gerätezustand meinen und gehört nicht in die Verweigerungsrate. Der Bericht führt beide getrennt.
4. **Gerät:** iPhone nur nach Hennings wörtlichem „jetzt ist ein Test möglich“; die Mac-Messung ist eigener Rechner und erlaubt. Der Mac hat laut Memory eine ältere Modellgeneration,
   deshalb zählen beide Geräte getrennt und der Mac ersetzt das iPhone nicht.
5. **Messkorpus-Größe:** 100 heikle Texte tragen eine 1-%-Schwelle statistisch kaum (ein Treffer = 1 %). Der Bericht muss das nennen und die 287 FocusBlox-Texte als Alltagsmenge dazunehmen.
6. **Kein Produktpfad:** Es berührt weder `Shared/Persistence`, `EnrichmentCoordinator` noch die Geräteliste. Stufe 3 greift nur wegen der Messung selbst, nicht wegen einer Diff-Datei.

## Analysis

### Type
Feature (Spike, Messung). Kein Bug: Es gibt keinen beobachteten Fehler in Hennings Alltag, die Annahme B3 wird geprüft.
„Hat es bisher funktioniert?“ trifft nicht zu — die Messung ist neu.

### Recherche (zuerst, Stand 2026-10-27)
- [Forum 793876](https://developer.apple.com/forums/thread/793876): „I need to go to Six Flags Great America tomorrow at 3pm.“ → `guardrailViolation`; Apple: ab Beta 4 vieles behoben.
- [Forum 787736](https://developer.apple.com/forums/thread/787736): harmlose Texte (Nachrichten, Camping, Titel aus Buchauszug) werden abgelehnt, **nicht deterministisch**, auch unter iOS 27 berichtet. `.permissiveContentTransformations` ist der Apple-Hinweis.
- [Forum 835777](https://developer.apple.com/forums/thread/835777): Fehlalarme ab iOS/macOS 26.5; `.permissiveContentTransformations` greift laut Fragesteller **nicht bei `Generable`** — und genau das nutzt `FoundationModelsEnricher` (`respond(generating:)`). Der Schalter ist also kein Ausweg für uns.
- [WWDC26 Sitzung 241](https://developer.apple.com/videos/play/wwdc2026/241/): Fehlalarme seit 26.4 reduziert, in iOS 27 weiter verfeinert. [Sitzung 339](https://developer.apple.com/videos/play/wwdc2026/339/): `LanguageModelError` mit `guardrailViolation`, `refusal`, `rateLimited` getrennt. `refusal` kann auch ohne Guardrail-Verstoß kommen.
- Folge für die Messung: **ein Durchlauf je Text reicht nicht**, weil dieselbe Anfrage mal geht, mal nicht. Apple sagt zudem, das Verhalten hängt von der Sprache/Region ab.

### Befund im Code
- `MeasurementErrorKind.classify` trennt schon `guardrail`, `refusal`, `rateLimited`, `timeout`. Eine Auswertung je Art, Menge und Sprache fehlt.
- `Corpus.load` liest `guardrail-corpus.json` (id, lang, text) ohne Änderung. Der FocusBlox-Korpus hat `rawText` (Produkteingabe) und `text` (Titel); `Corpus.Entry` liest nur `text` → für die Messung wird `rawText` gebraucht, sonst messen wir Titel statt Hennings gesprochene Sätze.
- `MeasurementRunner` (Labor-App) wiederholt jeden Fehlschlag nach 60 s und stoppt nach 3 Fehlern in Folge; `remaining` zählt nur Erfolge. Ein dauerhaft abgelehnter Satz würde endlos neu versucht. Für B3 muss jeder Satz **einmal pro Durchlauf zählen, auch bei Fehlschlag**, hinter einem eigenen Schalter (`--count-failures`), damit #88/#534 unberührt bleiben.
- Im Produkt ist ein Guardrail-Treffer schon „dauerhaft“ (`ModelFailure.isPermanent`, #535): `processedAt` gesetzt, die Regelwerte bleiben. Verlust bei Verweigerung = nur die Modellverfeinerung (Titel, Dauer, Wichtigkeit/Dringlichkeit); der Titel steht schon durch `TitleRule` (#202).

### Ohne Modell geht es nicht, weil …
Für die **Messung** gilt die Regel „Regeln vor Modell“ nicht: Regeln verweigern nie, die Regel-Spalte ist 0 % per Konstruktion und wird im Bericht so geführt. Die Frage ist, was die Verweigerungsrate für das **Produkt** kostet — und das ist wenig, weil das Modell nur noch verfeinert. Das senkt das Gewicht der Schwelle, nicht den Wert der Messung (Tor für externe Tester, Epic #370).

### Statistik (muss in den Bericht)
387 Texte (287 + 100): 1 % ≈ 3,9 Treffer. Bei 0 Treffern liegt die obere 95-%-Grenze bei ≈ 0,8 % (Dreierregel 3/387), bei 1 Treffer bei ≈ 1,4 %. Auf den 100 heiklen allein trägt nichts (ein Treffer = 1 %, 0 Treffer → obere Grenze 3 %). Deshalb: Schwelle am Gesamtwert, beide Mengen einzeln ausgewiesen, jeder Treffer mit Wortlaut aufgelistet, Wiederholungen (2 Durchläufe) ausgewiesen als „immer / manchmal“.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Measurement/GuardrailReport.swift` | CREATE | Reine Auswertung: Rate je Fehlerart (guardrail, refusal, rateLimited, übrige getrennt), je Menge/Sprache/Gruppe, Treffer „immer/manchmal“, obere Grenze (Wilson/Dreierregel). Rate-Limit und Timeout zählen nicht in die Verweigerungsrate. |
| `LooseEndsTests/GuardrailReportTests.swift` | CREATE | Unit-Tests der Auswertung mit gestellten Ergebnissen (alle Fehlerarten, 0 Treffer, Wiederholung). |
| `LooseEndsTests/RealModelGuardrailTests.swift` | CREATE | Mac-Lauf mit echtem Modell nach Muster `RealModelLatencyTests` (`LOOSEENDS_REAL_MODEL=1`, nie in der CI), 2 Durchläufe, Rohdaten als JSON. |
| `Measurement/Corpus.swift` | MODIFY | `rawText` des FocusBlox-Korpus als Eingabe lesbar machen (kleiner Pfad, Standard unverändert). |
| `LooseEndsLab/MeasurementRunner.swift` + `Measurement/MeasurementRun.swift` | MODIFY | Schalter `--count-failures`: jeder Satz einmal je Durchlauf, kein Wiederholen/Dreifehler-Stopp (nur für Schnitt 2). |
| `scripts/sim.sh`, `scripts/guardrail_summary.py` | MODIFY/CREATE | `real-model-guardrail` (Mac) und Auswertung; `lab-guardrail` für das iPhone (nur nach Hennings Wort). |
| `docs/reference/modell-guardrails.md`, `docs/artifacts/71-guardrails/` | CREATE | Bericht mit Nulllinie, Rohdaten. |

### Schnittvorschlag (Scoping Limits)
Alles zusammen sprengt 4–5 Dateien. Deshalb zwei Schnitte:
1. **Schnitt 1 — Mac:** Auswertung + Tests + Mac-Lauf + Skript + Bericht (Mac-Spalte). ~4 Dateien, ~+230 LoC. Läuft ohne Hennings Gerät.
2. **Schnitt 2 — iPhone:** `--count-failures`, Lab-Aufruf, iPhone-Spalte im Bericht, gebündelt mit #88 Teil 2 in einem Gerätedurchgang. Wartet auf „jetzt ist ein Test möglich“.

### Scope Assessment
- Schnitt 1: 4–5 Dateien, ≈ +230 LoC, Risiko LOW (nur Messcode, kein Produktpfad).
- Schnitt 2: 3–4 Dateien, ≈ +120 LoC, Risiko LOW–MEDIUM (Läufer der Labor-App gemeinsam mit #88/#534).
- Geräteliste: berührt keinen Pfad der Liste; Stufe 3 greift nur, weil die Messung selbst das iPhone braucht.

### Alternativen (zum bisherigen Weg)
- **A. Nicht messen, nur das Verhalten absichern:** Im Produkt zeigt eine Verweigerung nichts Neues an, die Regelwerte bleiben. Reicht das als Sicherheitsnetz, kippt die Messung als Tor (B3 würde zur Beobachtung). Gegenargument: Annahme B3 ist ausdrücklich Teil des Tors für externe Tester (Epic #370); Henning wollte die Annahmen vor dem Bauen geprüft haben.
- **B. Eigenes Anzeigeelement „Modell hat abgelehnt“ statt stumm „ungeprüft“:** erst bauen, wenn die Rate über der Schwelle liegt (das ist die Alternative aus dem Ticket). Würde ADR-4 (Anreicherung läuft einmal) nicht kippen.
- **C. Nur Mac messen, iPhone weglassen:** spart den Gerätedurchgang, aber der Mac hat laut Memory die ältere Modellgeneration; das iPhone ist das Gerät der Tester. Nicht empfohlen.

### Empfehlung
Schnitt 1 jetzt bauen (Mac), Schnitt 2 mit #88 Teil 2 in einem einzigen Gerätedurchgang nach Hennings Wort. Zwei Durchläufe je Text, Schwelle am Gesamtwert über 387 Texte, Rate-Limit getrennt gezählt.

### Dependencies
#276 Korpus (gemergt), #535/#536 (Fehlerarten), #68, #88 Teil 2 (Bündelung), Downstream: B3 / Epic #370, bei Überschreitung ein Folgeticket für den sichtbaren Zustand.

### Open Questions
- [ ] Der FocusBlox-Korpus liegt nur in Hennings Hauptordner (gitignored, persönliche Daten). Für Schnitt 1 per Umgebungsvariable `LOOSEENDS_FOCUSBLOX_CORPUS` laden; für Schnitt 2 beim Bau des Prüfbaus in die Labor-App kopieren, nie einchecken. (Technische Entscheidung, Empfehlung steht.)
- [ ] „Alltagstext“ = alle 387 Texte gemeinsam (Empfehlung) oder nur die 287 echten? Wird in der Spec festgeschrieben.
