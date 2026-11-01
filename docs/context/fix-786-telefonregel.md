# Context: fix-786-telefonregel

## Request Summary
`RuleGoldenTests.matchesFixture` ist im iOS-27.0-Simulator rot: `TitleRule` entfernt „30021988“ aus „Die Police 30021988 …“,
weil `NSDataDetector` die Ziffernfolge unter iOS als Telefonnummer meldet, unter macOS nicht. Die Regel soll vom
Detector unabhängig werden, damit Titel und Notiz auf allen Geräten gleich ausfallen.

## Befund (2026-11-01, nachgestellt)
- `./scripts/sim.sh sim-unit RuleGoldenTests` (iPhone 17, iOS 27.0): 2 Abweichungen, `de-gemischt-8` und `de-zahl-10`, Titel ohne „30021988“.
- macOS 27.0.1 (de_DE), `swift` mit `NSDataDetector(.phoneNumber)`: „Die Police 30021988 umschreiben lassen“ → kein Treffer;
  „Ruf 040 1234567 an“ → „040 1234567“; „Kunde 1234567 anrufen“ → kein Treffer; „Nummer 0151 23456789“ → Treffer.
- CI `main` a48f72c (Lauf 41315426139): Job „Unit Tests (macOS destination)“ — Suite grün. Der iOS-Lauf für #776 wurde abgebrochen;
  die Fixture ist auf dem Mac-Ziel entstanden/bestätigt.
- Recherche: Apple-Forum 696101 (FB9804292) — `NSDataDetector` antwortet je nach Simulator-/OS-Version verschieden; zu reinen
  Ziffernfolgen keine Doku.
- Folge im Produkt: Auf iPhone/iPad wandert eine Policen-/Kundennummer seit #439 in die Notiz und fehlt im Titel; am Mac nicht.

## Related Files
| File | Relevance |
|------|-----------|
| `Shared/Enrichment/PhoneRule.swift` | Zu ändern: `ranges(in:)` nutzt `NoteLinks.hits` (`NSDataDetector`) |
| `Shared/Services/TitleRule.swift:30` | Ruft `PhoneRule.removing` — Titel ohne Nummer |
| `Shared/Enrichment/EnrichmentCoordinator.swift:418` | `applyPhoneRule` → `PhoneRule.note`; bleibt unverändert (Geräteliste!) |
| `Shared/Services/NoteLinks.swift` | Antippbare Links in der Notiz, bleibt beim Detector (Anzeige, nicht Erfassung) |
| `LooseEndsTests/PhoneRuleTests.swift` | Bestehende Tests (+49 251 465560) |
| `LooseEndsTests/RuleGoldenTests.swift`, `Fixtures/rule-golden.json` | Golden-Test, Fixture enthält „30021988“ im Titel |
| `LooseEndsTests/DateExpressionParserTests.swift:151,196`, `TimeExpressionParserTests.swift:67` | Gleicher Satz als Negativfall für Datum/Zeit |

## Existing Patterns
- Regeln vor Modell; eigene Parser (`DateExpressionParser`, `TimeExpressionParser`) statt `NSDataDetector`, weil dessen Spalte
  vom Wochentag abhing (#148). Gleiches Muster hier: deterministische eigene Regel.
- Sprachwörter gehören in `LanguagePack`; eine Telefonnummer-Form ist eher Zahlformat (0/+ Vorwahl) als Wortliste.

## Dependencies
- Upstream: `NoteLinks.hits` → `NSDataDetector`.
- Downstream: `TitleRule.title` (Erfassung, Golden-Test, Korpus-Abnahmen), `EnrichmentCoordinator.applyPhoneRule` (Notiz).

## Existing Specs
- `docs/specs/feat-439-notiz.md` — AC-5 (Titel ohne Nummer), AC-6 (Nummer in die Notiz).

## Risks & Considerations
- Eigene Regel darf echte Nummern nicht verlieren: +49 …, 0251 …, 040 1234567, 0151 23456789, mit Leerzeichen, „/“, „-“.
- Uhrzeiten, Daten, Dauern, Mengen („7 Kartons“, „15.03.“, „20 Minuten“) dürfen nicht als Nummer gelten.
- Englische Formate (+1 …, (555) 123-4567) — englisches Sprachpaket ist ausgeliefert.
- Geräteliste: `PhoneRule.swift` steht nicht darauf; `EnrichmentCoordinator.swift` nicht anfassen → Abnahme endet nach Stufe 2.
- Alternative: Fixture auf das iOS-Ergebnis setzen — Mac-Ziel würde rot, Geräte blieben uneinheitlich.

## Analysis

### Type
Bug — reproduziert. Gleiches Swift-Programm, 651 Korpussätze (`Measurement/*.json`) plus Grenzfälle, `NSDataDetector(.phoneNumber)`:
macOS 27 gegen iOS-27.0- und iOS-27.2-Simulator (`simctl spawn`). Unterschied **nur** bei reinen Ziffernfolgen ohne führende 0/+:
„Police 30021988“, „Kunde 1234567“, „Auftrag 12345678“ → iOS Treffer, Mac keiner. Alles andere identisch.
Beide Plattformen: „Rechnung 2025-0042“ → Treffer (Fehlalarm überall). Hat es bisher funktioniert? Auf dem Mac ja,
auf iPhone/iPad seit #439 nie für solche Zahlen. Kein Gerätelauf (keine Freigabe nötig, Simulator reicht als Beleg der Plattformdifferenz).

### Formen, die beide Detector-Läufe als Nummer führen (Soll für die eigene Regel)
`+49 251 465560`, `0251/465560`, `040 1234567`, `0151 23456789`, `01761234567`, `0176 1234 5678`, `02 51 / 4 65 56`,
`040-987654-0`, `040 987654 - 0`, `040 987654–0` (Gedankenstrich), `+49 (0) 251 465560`, `0049 251 465560`,
`0251␣465560` mit U+00A0 und U+202F, `(555) 123-4567`, `+1 415 555 0123`; Satzpunkt/Komma am Ende gehören nicht dazu.
Nicht als Nummer (Soll): `30021988`, `1234567`, `12345678`, `2025-0042`, `01067 Dresden`, `09:14`, `15.03.2026`, `4711`, IBAN.
Detector findet `0251.465560` nirgends → Punkt ist kein Trenner. Bekannter verbleibender Fehlalarm (wie Detector): `0815 4711 1234`.

### Prototyp (Python, `rule.py` im Scratchpad)
Beginn „+Ziffer“, „0Ziffer“ oder „(Ziffer“, vorn keine Ziffer/Buchstabe/+; Gruppen getrennt durch Leerzeichen, „/“ oder „-“
(optional umgeben von Leerzeichen); 7–15 Ziffern gesamt (E.164); zusätzlich nordamerikanisch 3-3-4. Ergebnis: auf allen 651
Korpussätzen exakt dieselben Treffer wie der Mac-Detector (40 Mail-Signaturen: 14× „040 123456-0“, 13× „040 555000-12“,
13× „040 987654-0“), alle Soll-Fälle oben bis auf die erst später gemessenen Unicode-/„(0)“-Fälle, die die Spec ergänzt.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Shared/Enrichment/PhoneRule.swift` | MODIFY | `ranges(in:)` als eigener Scanner über `Character` (ASCII-Ziffern), kein Detector, kein Regex |
| `LooseEndsTests/PhoneRuleTests.swift` | MODIFY | Positiv-/Negativtabelle oben, Range-Grenzen, Titel „Die Police 30021988 …“ behält die Zahl |
| `Shared/Services/TitleRule.swift` | MODIFY (Kommentar) | Doc-Kommentar nennt nicht mehr den Detector — nur falls er ihn nennt |
| `Shared/Services/NoteLinks.swift` | MODIFY (Kommentar) | Ein Satz: Anzeige-Links bleiben beim Detector, Erfassung nutzt `PhoneRule` |

### Scope Assessment
- Files: 2–4 · Estimated LoC: +60…+90 / −5 (Tests etwa so groß wie Code) · Risk Level: LOW
- Geräteliste: kein Pfad berührt (`EnrichmentCoordinator.swift` bleibt unverändert) → Abnahme endet nach Stufe 2.
- Fixture `rule-golden.json` bleibt unverändert (sie enthält bereits „30021988“ im Titel); Beweis: `RuleGoldenTests` grün im
  iOS-27.0-Simulator (vorher rot, 2 Abweichungen) und Mac-Ziel in der CI.

### Technical Approach
Eigene deterministische Regel in `PhoneRule` (Regeln vor Modell, Muster wie `DateExpressionParser` statt Detector, #148).
Scanner statt Regex (Review): `\d` in Swift-Regex ist Unicode-weit, Scanner gibt direkt `String.Index`-Ranges, passt zu
`NoteLinks.phoneURL` (ASCII-Ziffern). Trenner: Leerzeichen inkl. U+00A0/U+202F, „/“, „-“, „–“, optional mit Leerzeichen;
Klammergruppe „(0)“/„(555)“. Grenzen: davor kein Buchstabe/Ziffer/„+“, danach keine Ziffer; abschließende Trenner/Satzzeichen
gehören nicht zur Range.

### Alternativen
- A: `NoteLinks` (Anzeige-Links) ebenfalls auf `PhoneRule` umstellen — einheitlich, verliert aber Detector-Formate; anderer
  Zweck (Anzeige), daher eigenes Ticket, falls gewünscht. Bis dahin kann eine Notiz auf iOS „1234567“ antippbar zeigen (harmlos).
- B: Nur die Fixture auf das iOS-Ergebnis setzen — verworfen: Mac-Ziel würde rot, und auf dem iPhone verschwänden
  Policen-/Kundennummern weiter aus dem Titel.
- C: Zahlformate ins `LanguagePack` — dort gibt es keinen Platz für Formate, für zwei Formen (DE, NANP) übertrieben.
Gekippt wird keine ADR; nur die Wahl aus #439 „NSDataDetector findet sie“ für die Erfassung.

### Dependencies
Upstream bisher `NoteLinks.hits`; danach keine. Downstream unverändert: `TitleRule.title`, `EnrichmentCoordinator.applyPhoneRule`.

### Quellen
- Apple Developer Forums 696101 (FB9804292): `NSDataDetector` liefert je OS/Simulator-Version andere Treffer — https://developer.apple.com/forums/thread/696101
- Apple-Doku `NSTextCheckingResult.phoneNumber` (kein Verhalten zu reinen Ziffernfolgen dokumentiert) — https://developer.apple.com/documentation/foundation/nstextcheckingresult/phonenumber
- Deutsche Rufnummernform (Vorwahl mit 0 / +49, 2–5-stellige Vorwahl) — https://sent.dm/en/resources/phone-number-standards/de

### Open Questions
- keine (Folge-Ticket für Alternative A nur, wenn Henning einheitliche Links will)
