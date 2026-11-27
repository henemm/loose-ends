# Context: #1001 Regeln an eigenen Erfassungen schärfen (Titel und Felder ohne Modell)

## Request Summary
Seit #982 (Epic #999, ADR-22) setzen nur noch Regeln Titel und Felder. Lücke laut Issue: „Pakete wegbringen heute Morgen“
→ Titel „Pakete wegbringen Morgen“. Ziel: Datumswörter samt Tageszeit vollständig aus dem Titel, nichts dazuerfunden;
Auswertung mit Zahlen (Anteil Titel ohne Korrektur vorher/nachher) im Issue; Fehlerklassen als Tests.

## Befund schon im Kontext (eingefrorene Regelausgabe `LooseEndsTests/Fixtures/rule-golden.json`)
Die Fehlerklasse ist im vorhandenen Datum/Titel-Korpus sichtbar, ohne Gerät:
- „Heute Abend um 20 Uhr Oma anrufen“ → „Abend Oma anrufen“
- „Müll rausstellen heute Abend“ → „Müll rausstellen Abend“
- „Morgen früh um 7:30 den Hund zum Tierarzt“ → „Früh den Hund zum Tierarzt“
- „Morgen Mittag um 12 die Bestellung …“ → „Mittag die Bestellung …“
- „… tomorrow morning hand in …“ → „… morning hand in …“

Ursache (Code): `TitleRule.strippingRuleWords` streicht nur die Spans von `DueDateRule.match` (+ `titleLeadIns`);
der Datumsparser kennt „heute/morgen“ (`relativeDays`), aber keine Tageszeitwörter (Abend, früh, Mittag, Morgen als
Tageszeit, morning, evening, tonight …). Sie bleiben stehen. „Morgen“ großgeschrieben nach „heute“ = Tageszeit.

## Related Files
- `Shared/Services/TitleRule.swift` (99 Z.) — Titel bei Erfassung, streicht Regelwörter
- `Shared/Enrichment/DueDateRule.swift` — liefert die Spans des Fälligkeitsdatums
- `Shared/Services/DateExpressionParser.swift` (320), `TimeExpressionParser.swift` (164) — Datum/Uhrzeit
- `Shared/Language/GermanPack.swift`, `EnglishPack.swift`, `LanguagePack.swift` — Wortlisten je Sprache (`titleLeadIns`,
  `titleDateWords`; `fillerWords` enthält schon abend/abends/fruh/mittag)
- Tests: `LooseEndsTests/TitleRuleTests.swift`, `DateTitleReportTests.swift`, `RuleGoldenTests.swift` (+ Fixture,
  Neuschreiben mit `LOOSEENDS_UPDATE_GOLDEN=1`), `LanguagePackConformanceTests`
- Korpora: `Measurement/date-title-corpus.json` (345 Sätze), `textform-corpus.json`, `convention-corpus.json`;
  `docs/reference/focusblox-corpus.json` (287 eigene FocusBlox-Erfassungen, nicht eingecheckt, nur im Hauptordner;
  `title == rawText` überall, also keine Titelkorrekturen darin)

## Datenlage für „Hennings eigene Korrekturen“
- Echte Titelkorrekturen liegen nur in seinem Loose-Ends-Speicher (Mac-App). Export: `docs/reference/messung-rohsaetze.md`
  (`RawTextExport` → `docs/reference/loose-ends-rawtexts.json`), Auswertung `Measurement/RawSentenceColumn.swift`.
- ⛔ Lesen seines echten Speichers = Zugriff auf sein Gerät: erst nach wörtlich „jetzt ist ein Test möglich“.
- Der Claude-Dienst liefert Titel, aber keinen Rohtext (TranscriptCodec) → kein Ersatz.

## Existing Patterns
- Regelwörter je Sprache im `LanguagePack` (ein Feld je Wortklasse), Konformanztests halten Tabellen sauber.
- Titel streicht nur, was eine Regel als Feld setzt (#217); Ausnahme Telefonnummer (#439).
- Goldene Regelausgabe: absichtliche Änderung → Fixture neu schreiben, Diff prüfen.

## Dependencies / Dependents
- `TitleRule` wird bei Erfassung aufgerufen (CaptureService); Claude- und Tastatur-Titel bleiben unberührt (#953, #950) → in Analyse prüfen.
- `DueDateRule` wird auch für Teilaufgaben-Zeilen benutzt (#565).

## Risks
- Tageszeitwort als Inhalt: „Morgenrunde laufen“, „Abendessen kochen“, „Mittagessen“ dürfen nicht gestrichen werden
  (Wortgrenze, nur direkt am Datumsausdruck).
- „Morgen“ allein am Satzanfang = Datum (morgen); „heute Morgen“ = Tageszeit; nicht doppelt deuten.
- Soll eine Tageszeit auch eine Uhrzeit setzen („heute Abend“ → 18:00)? Wäre Erfinden; „nichts dazuerfunden“ spricht dagegen.
- Golden-Fixture ändert sich in vielen Zeilen; jede Änderung im Diff ansehen.

## Analysis

**Type:** Feature (Regel verbessern), ein Schnitt.

**Befund (im Code geprüft):** `DateExpressionParser.best` nimmt den frühesten Kandidaten; „heute Morgen“ liefert also schon
Datum heute (Span nur „heute“), „Morgen“ bleibt nur im Titel stehen. Tageszeiten kennt kein `LanguagePack`-Feld.
`titleDateWords` ist nur das alte Modell-Titel-Verbot (#507), nicht die Streichung — dort nicht anbauen.
In der goldenen Ausgabe betroffen: 6 Zeilen (de-heute-2, de-morgen-2, de-zeit-5, de-zeit-hinten-2, de-lang-1 „morgen früh“, en-long-1);
nicht betroffen, weil kein Datum angrenzt: „morgens …“, „früh los“, „früh am Morgen“, „Samstagmorgen“ (ein Wort).
Die übrigen „Datumswörter“ im Titel sind Wiederholungen („Jeden Montag …“): absichtlich, keine Regel setzt eine Wiederholung.

### Affected Files
| Datei | Change | Grund |
|---|---|---|
| `Shared/Language/LanguagePack.swift` | MODIFY | neues Feld `dayParts` + Zugriff `LanguagePacks.dayParts` |
| `Shared/Language/GermanPack.swift` | MODIFY | de: abend, früh, mittag, vormittag, nachmittag, nacht, morgen (nur direkt nach „heute“) |
| `Shared/Language/EnglishPack.swift` | MODIFY | en: morning, afternoon, evening, night, noon; „tonight“ als relativeDay 0 |
| `Shared/Services/TitleRule.swift` | MODIFY | Datums-Span um direkt angrenzende Tageszeitwörter erweitern, samt „am“/„in the“ davor |
| Tests: `TitleRuleTests.swift`, `Language/TestPack.swift`, Konformanztests, `Fixtures/rule-golden.json` | MODIFY | RED-Fälle, Golden neu (Diff = genau diese Zeilen + tonight) |
| `docs/reference/neue-sprache.md` | MODIFY | Punkt „Tageszeiten“ für neue Sprachen |

**Scope/Risk:** ca. 70 LoC App-Code, 4 App-Dateien; Risiko niedrig–mittel (Erfassungspfad aller Kanäle über `CaptureService`,
aber nur Streichen im Titel; Feldwerte unverändert außer „tonight“ → Datum heute).

### Technical Approach (Variante A, empfohlen)
- Tageszeitwort wird nur gestrichen, wenn es **direkt** an einen Datums-Span grenzt (davor oder dahinter, ggf. über „am“/„in the“).
  Ohne Datum bleibt alles stehen („am Abend Tabletten“). Ganze Wörter: „Abendessen“, „Morgenrunde“ bleiben.
- „morgen“ ist Tageszeit nur direkt nach einem Tag-Span (heute/Wochentag): „heute Morgen“, „Montag Morgen“; „morgen früh“ = Datum + Tageszeit.
- Keine Uhrzeit aus der Tageszeit (wäre erfunden, Variante C verworfen); Parser bleibt unangetastet (Variante B verworfen:
  mehr Code, gleiches Ergebnis im Titel).
- Informationsverlust? Nein: der Rohtext bleibt unverändert und steht im Detail; das Issue verlangt das Streichen auch ohne Uhrzeit
  („Pakete wegbringen heute Morgen“). Alternative (verworfen): nur mit gesetzter Uhrzeit streichen — erfüllt das Issue-Beispiel nicht.
- „tonight“ → Datum heute (deterministisch, 1 Zeile). „heute Nacht“: Datum kommt schon von „heute“, „Nacht“ wird gestrichen.

- Risiko Inhaltswort neben Datum: `tf-02.english` „Parents' evening …“ — Tageszeit nach Genitiv/Inhaltswort ist Inhalt;
  gestrichen wird nur, was unmittelbar am Datums-Span (oder dessen Lead-in) hängt. Golden-Diff muss das zeigen.

### Alternative (mit ADR)
- Statt Regel-Liste: Titel = Rohtext unverändert, Datum nur im Feld (kein Streichen) — kippt #217 (Henning 2026-10-06), verworfen.

### Open Questions
- Zahlen „Anteil Titel ohne Korrektur vorher/nachher“ an Hennings **eigenen** Korrekturen: liegen nur im Speicher seiner Mac-App
  (Export `docs/reference/messung-rohsaetze.md`). Lesen = Zugriff auf sein Gerät → nur nach wörtlich „jetzt ist ein Test möglich“.
  Ohne seine Freigabe: Zahlen aus den eingecheckten Korpora (345 Datum/Titel-Sätze: Titel mit liegengebliebener Tageszeit 5 → 0).
- 2026-11-27: Henning hat per Auswahl „Ja, Mac-Daten lesen“ gewählt; der Export läuft erst nach seinem getippten
  „jetzt ist ein Test möglich“ (Regel Geräte). Spec erst nach der Auswertung, weil sein Korpus weitere Fehlerklassen zeigen kann.

## Auswertung Hennings eigene Erfassungen (2026-11-27, nach „jetzt ist ein Test möglich“)
Export einmal lesend aus der Mac-App (229 Sätze, Datei `docs/reference/loose-ends-rawtexts.json`, nicht eingecheckt;
Auswerteprogramm im Scratchpad, kompiliert `TitleRule` + Abhängigkeiten mit swiftc). Vergleich wortweise wie `RawSentenceColumn`.
- 41 Sätze mit Titelkorrektur. Heutige Regel trifft seinen Titel bei **14 von 41 (34 %)**.
- Von den 27 Abweichungen sind regelseitig behebbar: **2** — beide Klasse Tageszeit am Datum
  („Heute Abend … schreiben“, „Pakete wegbringen heute Morgen“). Erwartet nach dem Schnitt: **16 von 41 (39 %)**.
- Nicht regelbar (kein Schnitt): Hörfehler der Spracherkennung (Namen, Fachwörter, 7×), inhaltliche Umformulierungen und
  Ergänzungen (13×), Anrede am Anfang („Hi …“, 1×), Kurzform „Abends erledigen“ (1×), „Erinnerung für <Tag>: …“ (1×:
  Datum gestrichen, „Erinnerung für“ bleibt; „für“ als Lead-in + Vorspann wäre eine eigene Regel, Einzelfall, nicht in diesem Schnitt),
  Telefonnummer vom Nutzer in den Titel geholt (1×), Testeintrag (1×).
- Datenschutz: Im Issue nur Zahlen und Klassen, keine Sätze (außer dem Issue-Beispiel).
