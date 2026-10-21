# Context: fix-534-modell-timeout

## Request Summary
Das Limit von 30 s je Modellaufruf (`EnrichmentCoordinator`, #530) ist geschätzt. Es soll aus einer Messung
der Latenz kalt und warm abgeleitet werden (Mac über `real-model`, iPhone über die Labor-App), mit Bericht
unter `docs/reference/`. Teil von Epic #563; #536 und #535 sind gemergt.

## Related Files
| File | Relevance |
|------|-----------|
| `Shared/Enrichment/EnrichmentCoordinator.swift:24-39` | `modelTimeout` = `.seconds(30)` als Vorgabe im `init`; einziger Ort der Zahl. `LooseEndsApp.swift:34` benutzt die Vorgabe. |
| `Shared/Enrichment/ModelDeadline.swift` | Rennen zwischen Aufruf und Timer, wirft `Exceeded(limit:)`; bleibt unverändert. |
| `Shared/Enrichment/FoundationModelsEnricher.swift:17-21` | Baut bei JEDEM Aufruf eine neue `LanguageModelSession`, kein `prewarm()`. „Kalt“ heißt hier: erster Aufruf im Prozess. |
| `LooseEndsTests/RealModelTests.swift` | Mac-Suite (#531), prüft heute nur `took < .seconds(30)`, sammelt keine Zahlen. 6 erfundene Notizen. Gate: `LOOSEENDS_REAL_MODEL=1`. |
| `LooseEndsTests/RealModelGateTests.swift` | Quelltext-Test der Gates; eine neue Mess-Suite muss dieselben Gates tragen. |
| `scripts/sim.sh:389-405` (`cmd_real_model`) | startet `RealModelTests` auf dem Mac (nur macOS >= Target, Apple Silicon), Ergebnis aus dem xcresult. |
| `scripts/real_model_result.py` | liest Testfälle und Meldungen aus dem xcresult; reicht für Bestanden/Fehlgeschlagen, nicht für Zahlenreihen. |
| `docs/reference/kaltstart-messung.md` | Vorbild für den Bericht (Tabelle Gerät/System/Bau/Weg/Läufe, Rohdaten unter `docs/artifacts/`). |

## Existing Patterns
- Messung im Test, Bericht als Markdown, Rohdaten als JSON unter `docs/artifacts/<name>/` (#22).
- Jeder Messbericht führt die Regel-Spalte (Regeln vor Modell). Für Latenz gibt es keine Regel, die das Modell ersetzt.
  Der Bericht belegt deshalb, wofür das Modell noch gebraucht wird: `TitleRule` setzt den Titel schon beim Erfassen (#202),
  das Datum setzt die Regel (#95), die Kontexte setzt das Modell nie (#215).
- Mac-Hosting nur über `real-model` (ausdrücklich in CLAUDE.md), Unit-Tests sonst nur im Simulator.

## Dependencies
- Upstream: `SystemLanguageModel.default`, `LanguageModelSession.respond(to:generating:)` (FoundationModels).
- Downstream: `LooseEndsApp` (Coordinator); `ReanalysisTests`, `EnergyTests`, `PhoneRuleTests` laufen mit Stub und brauchen die Vorgabe nicht.

## Recherche (zuerst, vor der Analyse)
- Apple: `LanguageModelSession.prewarm(promptPrefix:)` lädt Ressourcen vorab, sinnvoll nur bei >= 1 s Vorlauf, nicht garantiert,
  besonders im Hintergrund oder unter Last.
  https://developer.apple.com/tutorials/data/documentation/foundationmodels/languagemodelsession/prewarm(promptPrefix:).md
- Apple-Forum: Prewarm gilt nur für die Instanz, auf der es aufgerufen wird, best effort; das System kann es ignorieren,
  wenn andere Apps das Modell nutzen. https://developer.apple.com/forums/thread/844222
- Fallbericht: Modell lädt bei Bedarf, 1–2 s Kaltstart (anekdotisch, keine Messung).
  https://drobinin.com/consulting/foundation-models-apple-intelligence/putting-apple-foundation-models-in-a-real-app/
- Keine veröffentlichte Latenzmessung von Apple gefunden. Das stützt die Messung, ersetzt sie nicht.

## Befunde für die Analyse
- Der Mac ist jetzt macOS 27.0.1 auf arm64 (`sw_vers`). Die ältere Notiz „Mac = alte Modellgeneration“ gilt damit nicht mehr
  ungeprüft. Ob Mac und iPhone dieselbe Modellgeneration haben, hält die Messung fest, es wird nicht angenommen.
- Eine kalte Probe entsteht nur je neuem Prozess: eine `real-model`-Runde liefert genau eine. Mehrere kalte Proben brauchen
  mehrere Läufe (`test-without-building`) und eine Mess-Datei als Rückkanal, denn das xcresult trägt keine Zahlenreihen.
- „Kalt“ auf Systemebene (das Betriebssystem hält das Modell noch im Speicher) lässt sich im Test nicht erzwingen.
  Der Bericht benennt, was gemessen wurde: prozess-kalt.

## Risks & Considerations
- Stufe 3: `EnrichmentCoordinator.swift` steht auf der Geräteliste. Der Gerätelauf (TestFlight) kommt erst nach Hennings
  „jetzt ist ein Test möglich“.
- Zu enges Limit: jede erste Anreicherung scheitert und wird erst im nächsten Durchlauf nachgeholt. Zu weites: ein Hänger hält
  den Durchlauf länger auf. Seit #535 werden dauerhafte Fehler nicht wiederholt, ein Timeout zählt aber als vorübergehend.
- Die Testsperre `/tmp/loose-ends-testlauf.lock` holt `sim.sh` selbst. Restock hält sie teils von Hand: nachfragen, nie löschen.
- Alternativen zur festen Zahl: zwei Grenzen (erster Aufruf nach Start großzügig, danach eng) oder `prewarm()` beim Start.
  Letzteres ändert den Enricher und wäre ein eigenes Ticket.

## Analysis

### Type
Feature (Messung und Konstante ableiten). Es ist kein Fehler: Nichts ist reproduzierbar kaputt, die 30 s sind eine ungeprüfte Annahme (Folge aus #530). „Hat es bisher funktioniert?" Ja, es ist kein Ausfall gemeldet.

### Root Cause / Befund
Die Zahl `.seconds(30)` steht an genau einer Stelle (`EnrichmentCoordinator.init`, Zeile 24-39) ohne Messbeleg. Es fehlt eine Latenzreihe. `RealModelTests` prüft nur `took < 30 s`, schreibt aber keine Zahlen. Das xcresult trägt keine Zahlenreihen (`real_model_result.py` liest nur Bestanden/Fehlgeschlagen). Die Labor-App (`MeasurementRunner`) misst Diagnose-Korpus-Sätze gegen das Modell, ist aber nicht auf Latenz je Aufruf ausgelegt.

Ohne Modell geht es nicht (Rückbezug auf „Regeln vor Modell"): Dieses Ticket führt kein Modell ein. Es belegt das Limit eines bestehenden Aufrufs. Die Regel-Spalte entfällt, weil es für Latenz keine Regel gibt, die das Modell ersetzt. Der Bericht nennt, wofür das Modell noch gebraucht wird: nur die Titelverfeinerung (Titel setzt `TitleRule` beim Erfassen, Datum die Regel, Kontexte nie das Modell).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEndsTests/RealModelLatencyTests.swift` | CREATE | Mess-Suite, gleiche Gates wie `RealModelTests` (`LOOSEENDS_REAL_MODEL`); ein Aufruf je Prozess für „kalt", danach N warme; schreibt Rohwerte als JSON in einen per Umgebungsvariable benannten Pfad |
| `LooseEndsTests/RealModelGateTests.swift` | MODIFY | Quelltext-Test erweitert um die neue Suite |
| `scripts/sim.sh` | MODIFY | `real-model-latency <n>`: n Prozesse nacheinander (`build-for-testing` einmal, dann `test-without-building`), sammelt die JSON-Dateien |
| `scripts/latency_summary.py` | CREATE | Median, p95, Maximum je Gruppe (kalt/warm) aus den Rohdaten |
| `docs/reference/modell-latenz.md` | CREATE | Bericht, Rohdaten unter `docs/artifacts/534-modell-latenz/` |
| `Shared/Enrichment/EnrichmentCoordinator.swift` | MODIFY | Vorgabe aus der Messung ableiten, Kommentar mit Verweis auf den Bericht (nur eine Zahl und ein Kommentar) |

Hinweis: Das iPhone-Messen ist nicht in dieser Dateiliste, weil die Labor-App unverändert bleibt, falls ihre Ergebnisdatei die Dauer je Aufruf schon trägt. Das prüft die Spec (`MeasurementStore`/`MeasurementRun`). Trägt sie keine Dauer, kommt ein Feld in `MeasurementRunner` hinzu (+1 Datei).

### Scope Assessment
- Files: 5-6
- Estimated LoC: +230/-5
- Risk Level: LOW für das Produkt (eine Konstante), MITTEL für die Messung (Prozess-kalt ist nicht System-kalt)
- Grenze: knapp am 4-5-Dateien-Limit. Falls die Labor-App ein Feld braucht, wird das Gerätemessen als Schnitt 2 abgetrennt.

### Technical Approach (Empfehlung)
1. Mac zuerst: je Prozess ein kalter Erstaufruf, danach 10 warme Aufrufe mit den 6 Notizen aus `RealModel.notes`. Etwa 15 Prozesse, also 15 kalte und etwa 150 warme Proben. Rohdaten als JSON, Auswertung per Skript.
2. Mess-Suite mit denselben Gates wie `RealModelTests`: ohne die Variable übersprungen, nie in der CI.
3. iPhone über die Labor-App (Stufe 3): erst nach Hennings wörtlichem „jetzt ist ein Test möglich". Bis dahin bleibt der Gerätepunkt der DoD offen.
4. Limit ableiten: Maximum der kalten Proben (Mac und iPhone, das größere) mit Faktor 3 bis 4 Abstand, aufgerundet. Die Zahl steht im Bericht samt Rechnung. Der Kommentar in `EnrichmentCoordinator` verweist darauf.

### Alternativen (Pflicht)
- **A: eine feste Grenze, aus der Messung abgeleitet** (Empfehlung). Kleinste Änderung, erfüllt die DoD wörtlich.
- **B: zwei Grenzen** (erster Aufruf nach Start großzügig, danach eng). Hängt ein warmer Aufruf, hält er den Durchlauf so kürzer auf. Lohnt nur, wenn die Messung kalt und warm um mehr als etwa Faktor 5 auseinanderlegt. Der Bericht entscheidet das mit Zahlen, die Spec wird dann angepasst.
- **C: `prewarm()` beim Start.** Würde die kalte Zeit verkürzen, ändert aber den Enricher und ist best effort (Apple-Doku, Forum). Eigenes Ticket, kippt keine ADR, setzt aber die Messung als Vorher-Wert voraus.
- **D: gar kein Limit.** Würde #530 zurücknehmen: ein Hänger hielte den Durchlauf endlos auf. Verworfen.

### Befunde, die gegen den Plan sprechen
- „Kalt" bedeutet hier prozess-kalt. Ob das Betriebssystem das Modell nach einem Neustart oder iOS-Update zusätzlich neu laden muss, lässt sich im Test nicht erzwingen. Der Bericht sagt das offen. Das Limit bekommt deshalb einen Sicherheitsfaktor und gilt nicht als Beweis für den Neustartfall.
- Der Mac (macOS 27.0.1) ist nicht automatisch dieselbe Modellgeneration wie das iPhone 16 Pro. Der Bericht hält beide Werte getrennt fest, abgeleitet wird aus dem größeren.
- Wenige kalte Proben ergeben kein belastbares p95. Der Bericht nennt n und gibt nur das Maximum als Grenzwert an, p95 nur als Beschreibung.
- Die Testsperre `/tmp/loose-ends-testlauf.lock` kann von Restock gehalten werden: nachfragen, nie löschen.

### Dependencies
`FoundationModelsEnricher` (unverändert), `ModelDeadline` (unverändert), `sim.sh`-Sperre, `real_model_result.py` (unverändert).

### Open Questions
- [ ] Trägt die Ergebnisdatei der Labor-App schon eine Dauer je Aufruf? Wird in `/30-write-spec` geprüft.
- [ ] Gerätelauf: erst mit Hennings „jetzt ist ein Test möglich". Braucht er das Gerät für die DoD, oder genügt der Mac, falls die Labor-App keine Dauer trägt? Das ist eine Produktfrage zum Umfang, wird in der Spec als Schnitt 2 vorgeschlagen.

### Quellen
Apple `LanguageModelSession.prewarm(promptPrefix:)`; Apple-Forum-Thread 844222; Fallbericht drobinin.com (siehe Abschnitt Recherche). Keine veröffentlichte Latenzmessung von Apple gefunden.
