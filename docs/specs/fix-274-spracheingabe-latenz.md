---
entity_id: fix-274-spracheingabe-latenz
type: bugfix
created: 2026-10-09
updated: 2026-10-09
status: draft
workflow: fix-274-spracheingabe-latenz
---

# Spec: #274 — Spracheingabe liefert das erste Wort nach ~1 s statt ~12 s

## Approval

- [ ] Approved (Henning)

## Purpose

Zweiter Schnitt zu #274 (gehört zu #279 Teil A: Verzögerung, stoßweise Ergebnisse). Die Diagnosezeile aus Schnitt 1
(PR #290, Build 21) zeigte auf Hennings iPhone 16 Pro: „Noch kein Text – Modell: installed · Mikrofon: ja · Sprache: ja ·
Puffer: 71 · Ergebnisse: 0“. Der Text kam später doch, und die Erfassung wirkte, als starte sie nicht.

**Ursache (am Mac reproduziert, 2026-10-09, macOS 27.0.1, deutsches Sprachmodell `installed`):** Die App erzeugt den
`SpeechTranscriber` mit `reportingOptions: [.volatileResults]` (`LooseEnds/Speech/SpeechCapture.swift:187`). Ohne
`.fastResults` sammelt `SpeechAnalyzer` rund 12 s Ton, bevor das erste Ergebnis kommt, egal wann gesprochen wird, und meldet
danach in Schüben. Wiederholbarer Versuch: `docs/artifacts/fix-274-spracheingabe-latenz/probe.swift` mit Ton aus
`say -v Anna` in Echtzeit-Paketen zu 100 ms, gemessen ab Fütterungsbeginn:

| Aufnahme | heute `[.volatileResults]` | mit `.fastResults` |
|---|---|---|
| 22 s, Sprache ab 4 s | erstes Wort 12,2 s, dann Schübe | 5,0 s (= ca. 1 s nach Sprechbeginn), danach jede Sekunde |
| 7 s kurz | erst am Ende (7,7 s) | 1,08 s |

Der Endtext ist bei beiden Einstellungen Wort für Wort gleich. `prepareToAnalyze`, Zeitstempel an `AnalyzerInput` und
Apple-Intelligence-Dauerlast hatten keinen Einfluss. Die frühere Spur „Hauptstrang belegt“ ist damit widerlegt, ebenso die
Deutung des ersten Schnitts „Prüfbau schnell“: Dessen Läufe 2–5 lieferten den ersten Text immer nach 13,4–14,2 s, also im
selben 12-s-Fenster. Quellen: Apple-Forum https://developer.apple.com/forums/thread/794720 (`[.volatileResults, .fastResults]`
als Latenzhebel), SDK-Schnittstelle `Speech.swiftinterface` (`ReportingOption.fastResults`).

**Fix:** `reportingOptions: [.volatileResults, .fastResults]`. Die Erzeugung des Transcribers wird dazu eine testbare
statische Fabrik mit der Sprache als Parameter, damit der Test genau denselben Transcriber wie die App benutzt.

Regelweg-Vermerk (Regeln vor Modell): Hier kommt kein Modell im Sinne des Projekts vor. Spracherkennung ist eine
Systemfunktion; es wird nur eine Option des Systems gesetzt. Die Frage „ohne Modell geht es nicht, weil …“ stellt sich nicht.

## Source

- **Geändert:** `LooseEnds/Speech/SpeechCapture.swift` (`transcriber()` wird `static func makeTranscriber(locale:)` plus
  Locale-Suche; Option `.fastResults`)
- **Neu:** `LooseEndsTests/SpeechLatencyTests.swift`
- **Neu:** `LooseEndsTests/Fixtures/speech-de.m4a`

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `LooseEnds/Speech/SpeechCapture.swift` | MODIFY | Neu `static func makeTranscriber(locale: Locale) -> SpeechTranscriber` mit `transcriptionOptions: []`, `reportingOptions: [.volatileResults, .fastResults]`, `attributeOptions: []`. `transcriber()` behält die Locale-Suche (`supportedLocale(equivalentTo: .current)`, Protokollzeile bei Fehlschlag) und ruft die Fabrik. Sichtbarkeit `internal` (Test über `@testable import`). Sonst keine Änderung an Analyzer, Tap, Wandler, Rechten, Diagnosezeile. |
| `LooseEndsTests/SpeechLatencyTests.swift` | NEU | Mac-Host-Test, siehe Test Plan. |
| `LooseEndsTests/Fixtures/speech-de.m4a` | NEU | Deutscher Testsatz, ca. 10 s, aus `say -v Anna`, AAC, mono, klein (unter 150 KB). Ein Satz mit Sprechbeginn nach ca. 1 s Stille, damit „Sprechbeginn“ im Test eine feste Konstante ist. |

Geschätzt **+85 / −4 LoC** (Produktcode ca. 8, Test ca. 75). Drei Dateien, innerhalb der Scoping-Limits.

**`project.yml`:** Voraussichtlich unverändert. Die Quelle `LooseEndsTests` ist ein Verzeichnis; XcodeGen legt Dateien ohne
Quellcode-Endung (hier `.m4a`) automatisch als Ressource ins Test-Bundle. Das wird in der Umsetzung am erzeugten Bundle
geprüft (Datei liegt im Bundle, `Bundle(for:)` findet sie). Nur wenn nicht, wird `project.yml` geändert (Ressource
ausdrücklich eintragen); das ist dann ein Treffer der Geräteliste, ohnehin gedeckt durch Stufe 3.

**Geräteliste berührt:** `LooseEnds/Speech/`. Stufe 3 (Hennings iPhone) ist Pflicht, aber **nur nach seinem wörtlichen
„jetzt ist ein Test möglich“**. Keine neuen Berechtigungen, keine AppStorage-Schlüssel, keine Audio-Dateien im Produkt, keine
Änderung an Persistenz, Modell, UI oder Texten.

### Nicht in diesem Ticket

- #279 B und C (Pegel, Mikrofon-Symbol): brauchen einen Entwurf.
- Messung der Startstrecke (Öffnen bis Zuhören) in der echten App: nur Folgeschritt, falls das Gerät nach dem Fix noch
  langsam startet.
- Preset `.progressiveTranscription` (siehe Alternativen).
- Rückbau auf `SFSpeechRecognizer`.
- Änderung der Diagnosezeile aus Schnitt 1: bleibt unverändert als Rückmeldekanal; mit ca. 1 s bis zum ersten Wort erscheint
  sie im gesunden Fall nicht mehr.

## Implementation Details

### Fabrik

```
static func makeTranscriber(locale: Locale) -> SpeechTranscriber
```

Liefert `SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [.volatileResults, .fastResults],
attributeOptions: [])`. Die Funktion ist die einzige Stelle, die den Transcriber der App erzeugt; `transcriber()` und der Test
gehen beide durch sie. Alle übrigen Parameter bleiben wie heute, damit Endtext und Verhalten außer der Latenz gleich sind.

### Test `SpeechLatencyTests`

Muster: Swift Testing (`import Testing`, `@Suite`, `@Test`), wie 65 von 66 Testdateien in `LooseEndsTests`. Lauf über
`./scripts/sim.sh unit` (voller Lauf; dort läuft der Mac als Host, sofern macOS ≥ Deployment Target).

Ablauf:

1. Sprache: `SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "de_DE"))`. Fehlt sie oder ist der Modellstatus
   nicht `installed` (`AssetInventory.status(forModules:)`), wird **sichtbar übersprungen** (`Issue.record` ist falsch; es
   wird ein Skip mit Begründung „Sprachmodell de_DE nicht installiert“ gemeldet, nicht ein stilles Grün). Das trifft CI und
   iOS-Simulator.
2. Transcriber: `SpeechCapture.makeTranscriber(locale:)` (derselbe wie die App).
3. Ton: Fixture mit `AVAudioFile` lesen, über `AnalyzerInputConverter` bzw. denselben Format-Weg wie `begin(with:)` in
   `AnalyzerInput`-Pakete zu 100 ms wandeln und **in Echtzeit** einspeisen (Wartezeit 100 ms je Paket), wie das Mikrofon.
4. Messung: Uhr startet mit dem ersten eingespeisten Paket; Sprechbeginn ist die Konstante des Fixtures (ca. 1 s).
   Zeitpunkt des ersten Elements aus `transcriber.results` mit nichtleerem Text wird gemerkt.
5. Zusicherungen: erstes Ergebnis **weniger als 3 s nach Sprechbeginn** (im Versuch ca. 1 s mit `.fastResults`, 12,2 s ohne);
   der Endtext (zusammengesetzte feste Ergebnisse) enthält die Kernwörter des Satzes (Groß-/Kleinschreibung ignoriert,
   mindestens drei markante Wörter, im Test fest hinterlegt).
6. Aufräumen: Eingabestrom beenden, `analyzer.finalizeAndFinishThroughEndOfInput()`; der Test hängt nicht, wenn nie ein
   Ergebnis kommt (Zeitlimit 30 s, danach Fehlschlag).

Der Test belegt die Ursache: Ohne die Option liefert dieselbe Strecke das erste Wort nach ca. 12 s und schlägt fehl.

## Test Plan

### Automated Tests (TDD RED zuerst)

`SpeechLatencyTests` (Mac-Host, Swift Testing):

- `firstWordArrivesWithinThreeSecondsOfSpeechStart`: wie oben. **RED vor dem Fix** (Fabrik mit nur `.volatileResults`,
  erstes Ergebnis ca. 12 s), **GRÜN nach dem Fix** (ca. 1 s nach Sprechbeginn).
- `finalTextContainsKeyWords`: Endtext enthält die Kernwörter; beweist, dass `.fastResults` den Inhalt nicht verschlechtert.
  (Beide Zusicherungen laufen aus einem Durchlauf, damit die Strecke nur einmal ca. 10 s dauert.)
- `makeTranscriberReportsFastResults`: schnelle Vorprüfung ohne Modell: `transcriber.reportingOptions` enthält `.volatileResults`
  und `.fastResults`. Läuft auch im Simulator und in CI und schützt die Option vor stillem Rückbau, wo der Zeittest
  überspringt. `reportingOptions` ist am Typ öffentlich lesbar (SDK 27, `Speech.swiftinterface`:
  `public var reportingOptions` an `SpeechTranscriber`, geprüft 2026-10-09).

RED-Nachweis: Der Test wird zuerst gegen die Fabrik mit `[.volatileResults]` ausgeführt und muss mit Zeit ca. 12 s fehlschlagen;
Ausgabe wird im Protokoll festgehalten. Erst dann wird die Option ergänzt.

### Abnahme (Stufen)

1. **Tests:** `./scripts/sim.sh unit` voll grün (Zeittest auf dem Mac-Host gelaufen, nicht übersprungen; im Protokoll stehen
   die gemessenen Sekunden).
2. **Simulator:** `./scripts/sim.sh build`, `launch`, Erfassung öffnen, Screenshot angesehen; UI-Smoke und Diagnose-Smoke
   (`SpeechDiagnosisLineTests`) unverändert grün. Der Simulator hat keine Sprachmodelle; er belegt nur, dass die Erfassung
   weiter öffnet.
3. **Gerät (Pflicht, `LooseEnds/Speech/` auf der Geräteliste):** Erst wenn Henning wörtlich „jetzt ist ein Test möglich“
   geschrieben hat; vorher wird nichts auf einem seiner Geräte gestartet, auch nichts Lesendes. Dann Prüfbau
   (`generate`, `device-build` auf genau dem Stand) und Hennings Beobachtung: Erfassung öffnen, sprechen, erstes Wort erscheint
   etwa 1 s nach Sprechbeginn, danach fortlaufend, die graue Zeile erscheint nicht. Anschließend neue TestFlight-Fassung;
   Henning bestätigt im Alltag. Zeigt das Gerät danach noch eine lange Startstrecke, ist die Zeitmessung (Öffnen bis
   Zuhören) der nächste Schnitt.

## Acceptance Criteria

- **AC-1 Option:** Given die App erzeugt den Transcriber / When `SpeechCapture.makeTranscriber(locale:)` läuft / Then enthält
  `reportingOptions` `.volatileResults` und `.fastResults`; `transcriber()` benutzt ausschließlich diese Fabrik.
- **AC-2 Erstes Wort:** Given deutsches Sprachmodell `installed` und Ton in Echtzeit-Paketen zu 100 ms / When der Satz beginnt /
  Then kommt das erste nichtleere Ergebnis weniger als 3 s nach Sprechbeginn (Versuch: ca. 1 s; vorher ca. 12 s).
- **AC-3 Inhalt:** Given derselbe Lauf / When der Satz zu Ende ist / Then enthält der Endtext die Kernwörter des Satzes
  (Groß-/Kleinschreibung ignoriert).
- **AC-4 Test rot, dann grün:** Der Zeittest schlägt mit der alten Option fehl (belegt, mit Zeitangabe im Protokoll) und
  besteht mit der neuen.
- **AC-5 Sichtbares Überspringen:** Given das Modell ist nicht `installed` (CI, Simulator) / When die Tests laufen / Then ist
  der Zeittest als übersprungen mit Begründung gemeldet, nicht grün gezählt.
- **AC-6 Nichts sonst:** Analyzer, Tap, Wandler, Rechte, Diagnosezeile (Schwelle 6 s), UI und Texte unverändert; Diff
  berührt nur die drei genannten Dateien (plus `project.yml` nur bei nachgewiesenem Bedarf).
- **AC-7 Regression:** Unit, Build, UI-Smoke und Speech Stress (10×, weil `LooseEnds/Speech/**` berührt) grün.
- **AC-8 Gerät:** Nach Hennings ausdrücklicher Freigabe bestätigt der Prüfbau auf dem iPhone das erste Wort kurz nach dem
  Sprechbeginn (Hennings Beobachtung); die TestFlight-Fassung wird ausgeliefert und von Henning im Alltag **auf iPhone und
  iPad** bestätigt (beide im Ticket betroffen). #274 und #279 A werden erst danach geschlossen.

## Dependencies

| Komponente | Version | Beschreibung |
|---|---|---|
| `Speech` (`SpeechTranscriber`, `SpeechAnalyzer`, `AssetInventory`) | iOS/macOS 27 | bestehend; `ReportingOption.fastResults` ist Teil derselben Schnittstelle |

Keine neue Abhängigkeit. Downstream `CaptureView` unverändert.

## Risiken

- **`.fastResults` bedeutet laut Apple „schneller, in Zwischenständen evtl. weniger genau“.** Im Versuch war der Endtext
  identisch (nur Großschreibung des ersten Worts); AC-3 sichert das im Test ab. Zwischenstände sind flüchtig und werden von
  den festen Ergebnissen ersetzt.
- **Der Mac-Test ersetzt das iPhone nicht.** Die Reproduktion läuft am Mac, nicht auf dem Gerät. Ob das iPhone dieselben 12 s
  zeigt, ist aus Hennings Zeile (Puffer 71 ≈ 7 s, Ergebnisse 0, Text später) und den Prüfbau-Läufen (13,4–14,2 s) sehr
  wahrscheinlich, bewiesen wird es erst in Stufe 3.
- **„Start dauert lange“ ist nicht getrennt gemessen.** Mit 12 s ohne Wort wirkt die Erfassung ungestartet; die Startstrecke
  im Prüfbau ist klein (713 ms, #22). Bleibt nach dem Fix ein Rest, folgt die Startstreckenmessung als eigener Schnitt.
- **Der Zeittest dauert ca. 10 s und hängt am installierten Modell.** Auf Maschinen ohne Modell wird er sichtbar
  übersprungen. Zeitlimit 30 s, damit er nie hängt. Schwelle 3 s gegen ca. 1 s Messwert lässt Reserve für Last auf dem Mac.
- **Fixture und Bundle:** Landet die `.m4a` nicht im Test-Bundle, schlägt der Test mit klarer Meldung fehl (kein stilles
  Überspringen); dann `project.yml` anpassen.

## Alternativen

- **Preset `.progressiveTranscription`:** gleiche Zeiten im Versuch (5,0 s bzw. 1,09 s), Apples Voreinstellung für Live-Diktat.
  Setzt aber eigene Transkriptions- und Attributoptionen fest, also mehr Änderung als nötig und Risiko für den Endtext.
  Bleibt die Alternative, falls `.fastResults` auf dem Gerät nicht trägt.
- **Erst messen, dann ändern** (Mess-Spec `docs/specs/fix-274-sprache-latenz-messung.md` der parallelen Sitzung, Worktree
  `linear-yawning-wigderson`): **abgelöst.** Die Ursache steht durch die Reproduktion fest; ein reiner Messschnitt würde nur
  eine TestFlight-Runde und Hennings Zeit kosten. Die Mess-Spec soll nicht freigegeben und nicht gebaut werden. Die
  Diagnosezeile aus Schnitt 1 bleibt als Rückmeldekanal.
- **Arbeit beim Start verschieben oder Ergebnis-Schleife vom Hauptstrang nehmen:** auf der Spur „Hauptstrang belegt“
  aufgebaut, die widerlegt ist (Reproduktion ohne App-Last, Diagnosezeile lief auf demselben Akteur).
- **Rückbau auf `SFSpeechRecognizer`:** unnötig, kippt „nur auf dem Gerät“ aus #64.
- **Nur gerätebasierter Beleg ohne Mac-Test:** wäre teurer (Hennings Gerät, nur nach seinem Wort) und nicht wiederholbar;
  der Mac-Test fängt einen Rückfall in jedem künftigen Lauf.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — eine Option an einer Stelle und eine Fabrikfunktion für die Testbarkeit; kein neues Konzept, kein
  Eingriff in Rohtext, Anreicherung, Revisions oder Persistenz. Kippt keine bestehende ADR.

## Definition of Done

- AC-1 bis AC-8 erfüllt; `SpeechLatencyTests` zuerst rot (mit gemessener Zeit), dann grün; alle bestehenden Tests grün.
- Das Protokoll des vollen Unit-Laufs nennt die gemessene Zeit bis zum ersten Wort.
- Simulator-Durchlauf (Erfassung öffnet) als Screenshot belegt und angesehen.
- Geräteabnahme nur nach Hennings wörtlichem „jetzt ist ein Test möglich“; danach TestFlight-Fassung ausgeliefert und
  von Henning auf iPhone und iPad bestätigt.
- `docs/project/04-stand.md` nennt den Fix und dass #274/#279 A erst nach Hennings Bestätigung im Alltag schließen.
- Abschlussbericht ohne Git-Vokabular: Sprache erscheint jetzt etwa eine Sekunde nach dem Sprechen statt nach zwölf; Henning
  soll in der TestFlight-Fassung die Erfassung öffnen, sprechen und melden, ob das erste Wort sofort kommt.

## Changelog

- 2026-10-09: Initiale Spec für #274, zweiter Schnitt: `.fastResults` am Transcriber, Ursache am Mac reproduziert; Mess-Spec
  der Parallelsitzung als abgelöst vermerkt.
