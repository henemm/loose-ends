---
entity_id: fix-786-telefonregel
type: bugfix
created: 2026-11-01
updated: 2026-11-01
status: draft
workflow: fix-786-telefonregel
---

# Spec: #786 — Telefonregel ohne NSDataDetector (Policennummer bleibt im Titel)

## Approval

- [ ] Approved (Henning)

## Purpose

Eine diktierte Telefonnummer geht in die Notiz und fehlt im Titel (#439). Die Regel dafür (`PhoneRule`) fragt den
`NSDataDetector`. Der meldet auf iPhone und iPad auch reine Ziffernfolgen wie „30021988“ (Policen-, Kunden-, Auftragsnummer) als
Telefonnummer, auf dem Mac nicht. Folge: `RuleGoldenTests.matchesFixture` ist im iOS-27.0-Simulator rot (2 Abweichungen:
`de-gemischt-8`, `de-zahl-10`), und im Produkt verschwindet die Nummer aus dem Titel und landet in der Notiz. Die Regel wird
vom Detector unabhängig, damit Titel und Notiz auf allen Geräten gleich ausfallen.

**Hat es bisher funktioniert?** Auf dem Mac ja. Auf iPhone und iPad nie für Ziffernfolgen ohne führende 0 oder „+“: der Fehler
steckt dort seit #439 in jedem Bau. Eine Verschlechterung durch eine spätere Änderung ist es nicht, sondern ein Plattformunterschied
von Anfang an; sichtbar wurde er erst, als die Golden-Fixture im iOS-27.0-Simulator lief.

### Root Cause (belegt im Nachbau, 2026-11-01)

- `PhoneRule.ranges(in:)` (`Shared/Enrichment/PhoneRule.swift`) ruft `NoteLinks.hits(in:)` und behält die Treffer der Art `.phone`.
  Die Treffer kommen aus `NSDataDetector`.
- `./scripts/sim.sh sim-unit RuleGoldenTests` (iPhone 17, iOS 27.0): 2 Abweichungen, `de-gemischt-8` und `de-zahl-10`, Titel ohne
  „30021988“.
- Gleiches Swift-Programm, 651 Korpussätze (`Measurement/*.json`) plus Grenzfälle, `NSDataDetector(.phoneNumber)`: macOS 27.0.1
  (de_DE) gegen iOS-27.0- und iOS-27.2-Simulator (`simctl spawn`). Unterschied nur bei reinen Ziffernfolgen ohne führende 0/„+“:
  „Police 30021988“, „Kunde 1234567“, „Auftrag 12345678“ → iOS Treffer, Mac keiner. Alles andere identisch.
- Auf beiden Plattformen Fehlalarm: „Rechnung 2025-0042“ → Treffer.
- CI `main` a48f72c (Lauf 41315426139): Job „Unit Tests (macOS destination)“ grün; die Fixture ist auf dem Mac-Ziel entstanden.

### Recherche (zuerst, 2026-11-01)

- Apple Developer Forums 696101 (FB9804292): `NSDataDetector` liefert je OS- und Simulator-Version andere Treffer. Zu reinen
  Ziffernfolgen steht nichts in der Dokumentation.
  https://developer.apple.com/forums/thread/696101
- Apple-Doku `NSTextCheckingResult.phoneNumber`: kein Verhalten zu reinen Ziffernfolgen dokumentiert.
  https://developer.apple.com/documentation/foundation/nstextcheckingresult/phonenumber
- Deutsche Rufnummernform (Vorwahl mit 0 oder +49, 2- bis 5-stellige Vorwahl):
  https://sent.dm/en/resources/phone-number-standards/de

### Regelweg-Vermerk (Regeln vor Modell)

Kein Modell beteiligt. Die Regel ersetzt einen Detector (`NSDataDetector`) durch eine eigene, deterministische Regel; die Frage
„ohne Modell geht es nicht, weil …“ stellt sich nicht. Muster wie bei `DateExpressionParser` und `TimeExpressionParser` (#148):
eigener Parser statt Detector, weil dessen Spalte vom Plattformstand abhing.

### Lösung

`PhoneRule.ranges(in:)` wird ein eigener Scanner über `Character` (nur ASCII-Ziffern), kein Detector, kein Regex. Ein Scanner statt
Regex, weil `\d` in Swift-Regex Unicode-weit passt, der Scanner direkt `String.Index`-Ranges liefert und zu `NoteLinks.phoneURL`
(ASCII-Ziffern) passt. Prototyp (Python, 651 Korpussätze): exakt dieselben Treffer wie der Mac-Detector, darunter 40
Mail-Signaturen (14× „040 123456-0“, 13× „040 555000-12“, 13× „040 987654-0“).

## Source

- **Geändert:** `Shared/Enrichment/PhoneRule.swift` (`PhoneRule.ranges(in:)` und neue private Hilfsfunktionen; Doc-Kommentar)
- **Geändert:** `LooseEndsTests/PhoneRuleTests.swift` (Swift Testing, Suite „Phone rule“)
- **Geändert:** `LooseEndsUITests/CaptureSmokeTests.swift` (zwei neue UI-Tests)
- **Geändert:** `Shared/Services/NoteLinks.swift` (ein Kommentarsatz)
- **Unverändert, geprüft:** `Shared/Services/TitleRule.swift` (Zeile 30 ruft `PhoneRule.removing`; der Kommentar dort nennt den Detector
  nicht, keine Änderung), `Shared/Enrichment/EnrichmentCoordinator.swift` (`applyPhoneRule`, Zeile 418; steht auf der Geräteliste und
  bleibt unberührt), `LooseEndsTests/Fixtures/rule-golden.json` (enthält „30021988“ im Titel bereits)

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `Shared/Enrichment/PhoneRule.swift` | MODIFY | `ranges(in:)` als eigener Scanner (Regeln unten), kein `NoteLinks`-Aufruf mehr; Doc-Kommentar: Regel statt Detector |
| `LooseEndsTests/PhoneRuleTests.swift` | MODIFY | Positiv-/Negativtabelle, Range-Grenzen, Satzzeichen am Ende, Titel „Die Police 30021988 umschreiben lassen“ behält die Zahl |
| `LooseEndsUITests/CaptureSmokeTests.swift` | MODIFY | zwei kleine Smoke-Tests (Police bleibt im Titel; Telefonnummer geht in die Notiz) |
| `Shared/Services/NoteLinks.swift` | MODIFY (Kommentar) | ein Satz: Anzeige-Links bleiben beim Detector, die Erfassung nutzt `PhoneRule` |

Vier Dateien. Geschätzt **+~180 / −~6 LoC**: Produktcode `PhoneRule` ca. +75/−3 (Scanner in Funktionen ≤ 50 LoC aufgeteilt),
Unit-Tests ca. +70, UI-Tests ca. +40, Kommentar +2. Innerhalb der Scoping-Limits (4–5 Dateien, ±250 LoC).

**Geräteliste berührt:** nein — Kein Pfad der Geräteliste berührt. (`PhoneRule.swift` steht nicht auf der Liste;
`EnrichmentCoordinator.swift` bleibt unverändert.) Die Abnahme endet nach Stufe 2.

**Side-Effects:** Keine Änderung an Info.plist, Entitlements, `project.yml`, AppStorage-Schlüsseln, Datenmodell, Texten
(`PhoneRule.reason` bleibt), Katalogen oder Audio-Dateien. Sichtbare Folge: Ziffernfolgen ohne führende 0/„+“ („Police 30021988“,
„Kunde 1234567“) bleiben im Titel und gehen nicht mehr in die Notiz, auf dem iPhone wie schon auf dem Mac; „2025-0042“ gilt nicht
mehr als Nummer. Bereits gespeicherte Notizen ändern sich nicht (kein Nachlauf, `rulesAppliedAt` bleibt).

### Nicht in diesem Ticket

- Die Anzeige-Links in der Notiz (`NoteLinks`, antippbar) bleiben beim Detector. Sie auf `PhoneRule` umzustellen ist Alternative A;
  eigenes Ticket nur auf Wunsch. Bis dahin kann eine Notiz auf iOS „1234567“ antippbar zeigen (harmlos).
- Neue Sprachwörter oder `LanguagePack`-Einträge (eine Nummernform ist Zahlformat, keine Wortliste).
- Weitere Länderformate über DE und NANP hinaus; IBAN, Postleitzahlen, Uhrzeiten werden nur als Negativfälle geprüft.
- Änderungen an `EnrichmentCoordinator`, `TitleRule`, an der Fixture oder bereits gespeicherten Aufgaben.

## Implementation Details

### Scanner-Regeln

`PhoneRule.ranges(in:)` läuft einmal über `Array(text)` (Character) und liefert `[Range<String.Index>]`, nicht überlappend, in
Reihenfolge des Vorkommens. „Ziffer“ heißt immer ASCII `0`–`9`.

1. **Beginn** an Position `i`, wenn eine der drei Formen gilt: „+“ gefolgt von einer Ziffer; „0“ gefolgt von einer Ziffer
   (also nicht die einzelne „0“); „(“ gefolgt von einer Ziffer.
2. **Davor** (Zeichen an `i − 1`) steht kein Buchstabe, keine Ziffer und kein „+“ (Wortmitte und „Rechnung2025“ zählen nicht).
3. **Gruppen**: Ziffernblöcke, getrennt durch einen Trenner. Trenner ist ein Leerzeichen (U+0020, U+00A0, U+202F), „/“, „-“ oder „–“
   (U+2013), optional von Leerzeichen umgeben („040 987654 - 0“, „02 51 / 4 65 56“). Ein Trenner trennt nur, wenn danach wieder eine
   Ziffer (oder eine Klammergruppe) folgt; sonst gehört er nicht zur Nummer.
4. **Klammergruppe**: „(0)“ oder „(555)“, die Klammer umschließt nur Ziffern (`(` Ziffern `)`), darf nach „+49 “ stehen
   („+49 (0) 251 465560“) oder am Anfang („(555) 123-4567“). Die Ziffern in der Klammer zählen zur Gesamtzahl.
5. **Länge**: 7 bis 15 Ziffern gesamt (E.164). Zusätzlich gilt die nordamerikanische Form 3-3-4 (zehn Ziffern) auch ohne führende 0.
6. **Ende**: auf die letzte Ziffer folgt keine weitere Ziffer (sonst zu lang, keine Nummer). Trenner und Satzzeichen am Ende
   („…465560.“, „…465560,“, „…465560 -“) gehören nicht zur Range.
7. **Punkt ist kein Trenner** („0251.465560“ ist keine Nummer; der Detector findet sie auf beiden Plattformen ebenfalls nicht).
8. Der Scan geht hinter einer Nummer weiter, hinter einem verworfenen Kandidaten ein Zeichen weiter (kein Rückwärtsgriff).

Aufteilung (alle ≤ 50 LoC): `ranges(in:)` (Schleife, Rand-Prüfung), `candidateEnd(in:from:)` (liest Gruppen und Trenner, liefert
Endindex und Ziffernzahl), `isValid(digits:groups:)` (Längenregel inkl. NANP 3-3-4). `numbers`, `removing`, `note` und `reason`
bleiben wie sie sind.

### Kommentar `NoteLinks`

Ein Satz am Typkopf: Die Anzeige-Links der Notiz kommen weiter vom `NSDataDetector`; die Erfassung (Titel, Notiz) nutzt `PhoneRule`,
damit sie auf allen Geräten gleich ausfällt (#786).

## Expected Behavior

- **Input:** diktierter oder getippter Satz.
- **Output:** `PhoneRule.ranges` meldet genau die Nummern der Positivtabelle; `TitleRule.title` entfernt sie aus dem Titel;
  `EnrichmentCoordinator.applyPhoneRule` schreibt sie (eine je Zeile) in eine leere Notiz.
- **Positiv (Soll, Nummer erkannt):**
  `+49 251 465560`, `0251/465560`, `040 1234567`, `0151 23456789`, `01761234567`, `0176 1234 5678`, `02 51 / 4 65 56`,
  `040-987654-0`, `040 987654 - 0`, `040 987654–0`, `+49 (0) 251 465560`, `0049 251 465560`, `0251 465560` mit U+00A0 und
  mit U+202F, `(555) 123-4567`, `+1 415 555 0123`.
- **Negativ (Soll, keine Nummer):** `30021988`, `1234567`, `12345678`, `2025-0042`, `01067 Dresden`, `09:14`, `15.03.2026`, `4711`,
  eine IBAN („DE89 3704 0044 0532 0130 00“), „7 Kartons“, „20 Minuten“, `0251.465560`.
- **Range-Grenzen:** „Ruf 040 1234567.“ → Range endet an der „7“; „Ruf 040 1234567, bitte“ → ebenso; „Ruf 040 1234567 -“ → ebenso.
- **Titel:** „Die Police 30021988 umschreiben lassen“ behält die Zahl; „Ruf 040 1234567 an“ → Titel ohne Nummer, Notiz „040 1234567“.
- **Side effects:** keine neuen.

## Test Plan

### Automated Tests (TDD RED zuerst)

`LooseEndsTests/PhoneRuleTests.swift` nutzt **Swift Testing** (`@Suite("Phone rule")`, `@Test`), nicht XCTest. Das QA-Gate des
Workflows zählt nur XCTest-Zeilen („Executed N tests“) und wertet einen Einzellauf einer Swift-Testing-Suite als „0 tests“. Deshalb
gilt als Beleg des Gates der **volle Lauf** `./scripts/sim.sh sim-unit`; der Einzellauf `./scripts/sim.sh sim-unit PhoneRuleTests`
dient der schnellen Rückmeldung. Die vorhandenen Tests bleiben unverändert; neue Tests im selben Stil:

- `@Test(arguments:)` **Positivtabelle**: je Eintrag ein Satz, der die Nummer enthält; erwartet: `PhoneRule.numbers(in:)` liefert genau
  die Nummer als geschrieben (alle Formen aus „Expected Behavior“).
- `@Test(arguments:)` **Negativtabelle**: erwartet: `PhoneRule.numbers(in:)` ist leer.
- **Range-Grenzen**: Satzpunkt, Komma und angehängter Trenner stehen nicht in der Range; `removing` lässt den Rest des Satzes unversehrt.
- **Mehrere Nummern**: zwei Nummern in einem Satz, beide in Reihenfolge; `note(from:)` trennt sie mit Zeilenumbruch.
- **Nur-Detector-Treffer** (`detectorOnlyDigitRunsAreIgnored`): „Kunde 1234567 anrufen“, „Auftrag 12345678 prüfen“ → `numbers` leer.
- **Titel behält die Zahl**: `TitleRule.title(from: "Die Police 30021988 umschreiben lassen")` enthält „30021988“.
- **Regelschritt**: bestehender Test `ruleStepWritesNote` bleibt grün; neuer Fall: bei „Die Police 30021988 umschreiben lassen“
  bleibt die Notiz leer (`task.notes == nil`), keine Notiz-Revision der Regel.

**RED vor der Änderung:** Die Negativ- und Titel-Fälle schlagen im iOS-27.0-Simulator fehl (Detector meldet „30021988“), und
`RuleGoldenTests.matchesFixture` ist rot mit den 2 Abweichungen `de-gemischt-8` und `de-zahl-10`.
**GREEN nach der Änderung:** `PhoneRuleTests` und `RuleGoldenTests` grün im iOS-27.0-Simulator; die Fixture bleibt unverändert.

### UI-Tests (Smoke)

Für #439 gibt es keinen UI-Test (Suche in `LooseEndsUITests` nach „Notiz“/„phone“/„439“/„Telefon“: nur den Notiz-Tippen-Test
`CaptureSmokeTests.testNoteIsTypedAndSaved` (#544), der die Regel nicht berührt). Geplant, in `CaptureSmokeTests` mit den vorhandenen
Hilfen `launch()` und `captureAndOpenDetail(_:in:)`:

- `testPolicyNumberStaysInTitleAndNoteStaysEmpty`: erfasst „Die Police 30021988 umschreiben lassen“, öffnet das Detail; erwartet:
  Titelfeld (`detailTitleField`) enthält „30021988“, das Notizfeld/der Notiztext (`noteText`) zeigt keinen Inhalt.
- `testPhoneNumberGoesToNoteNotTitle`: erfasst „Ruf 040 1234567 an“; erwartet: Titelfeld enthält „040“ nicht, `noteText` zeigt
  „040 1234567“.

Der Regelschritt läuft in der UI-Test-Umgebung ohne Modell (`--ui-testing`, Modell aus); er wartet nur auf den Abschluss des
Durchlaufs, daher `waitForExistence` mit Zeitgrenze statt fester Wartezeit. Beleg: `./scripts/sim.sh test-proof CaptureSmokeTests`.

### Abnahme (Stufen)

1. **Tests:** `PhoneRuleTests` und `RuleGoldenTests` grün im iOS-27.0-Simulator (vorher rot mit 2 Abweichungen `de-gemischt-8` und
   `de-zahl-10`); voller Lauf `./scripts/sim.sh sim-unit` grün; Mac-Ziel im CI-Job „Unit Tests (macOS destination)“ grün.
2. **Simulator:** App starten (`./scripts/sim.sh build`, `launch`), „Die Police 30021988 umschreiben lassen“ erfassen → Titel enthält
   die Zahl, Notiz bleibt leer; „Ruf 040 1234567 an“ erfassen → Titel ohne Nummer, Notiz mit „040 1234567“. Beleg per
   `./scripts/sim.sh test-proof CaptureSmokeTests` (Beleg `simulator-run.txt` plus Screenshots, Screenshots werden geöffnet und
   beschrieben).
3. **Gerät:** keine. Kein Pfad der Geräteliste berührt.

## Acceptance Criteria

- **AC-1:** Police bleibt im Titel: Given der Satz „Die Police 30021988 umschreiben lassen“ / When `TitleRule.title(from:)` und
  `PhoneRule.numbers(in:)` laufen (iOS-27.0-Simulator und Mac-Ziel) / Then enthält der Titel „30021988“ und `numbers` ist leer.
  Nachweis: Unit-Test in `PhoneRuleTests` und `RuleGoldenTests.matchesFixture` grün im iOS-27.0-Simulator (vorher rot mit
  `de-gemischt-8` und `de-zahl-10`, Fixture unverändert).
  - Test: LooseEndsTests/PhoneRuleTests.swift::policyNumberStaysInTitle, LooseEndsTests/RuleGoldenTests.swift::matchesFixture
- **AC-2:** Echte Nummern werden erkannt: Given jede Form der Positivtabelle (`+49 251 465560`, `0251/465560`, `040 1234567`,
  `0151 23456789`, `01761234567`, `0176 1234 5678`, `02 51 / 4 65 56`, `040-987654-0`, `040 987654 - 0`, `040 987654–0`,
  `+49 (0) 251 465560`, `0049 251 465560`, mit U+00A0, mit U+202F, `(555) 123-4567`, `+1 415 555 0123`) in einem Satz / When
  `PhoneRule.numbers(in:)` läuft / Then liefert es genau diese Nummer als geschrieben. Nachweis: parametrisierter Unit-Test.
  - Test: LooseEndsTests/PhoneRuleTests.swift::positiveFormsAreFound
- **AC-3:** Keine Fehltreffer: Given jede Form der Negativtabelle (`30021988`, `1234567`, `12345678`, `2025-0042`, `01067 Dresden`,
  `09:14`, `15.03.2026`, `4711`, IBAN, „7 Kartons“, „20 Minuten“, `0251.465560`) / When `PhoneRule.numbers(in:)` läuft / Then ist
  das Ergebnis leer. Nachweis: parametrisierter Unit-Test.
  - Test: LooseEndsTests/PhoneRuleTests.swift::negativeFormsAreIgnored
- **AC-4:** Range-Grenzen: Given „Ruf 040 1234567.“, „Ruf 040 1234567, bitte“ und „Ruf 040 1234567 -“ / When `PhoneRule.ranges(in:)` und
  `removing(from:)` laufen / Then endet jede Range an der letzten Ziffer; Punkt, Komma, Trenner und Leerzeichen am Ende gehören nicht
  dazu und bleiben im Rest des Satzes. Nachweis: Unit-Test.
  - Test: LooseEndsTests/PhoneRuleTests.swift::rangeEndsAtLastDigit, LooseEndsTests/PhoneRuleTests.swift::twoNumbersInOrder
- **AC-5:** Unabhängig vom Detector: Given die Sätze, in denen nur der iOS-Detector eine Nummer meldet („Kunde 1234567 anrufen“,
  „Auftrag 12345678 prüfen“, „Die Police 30021988 umschreiben lassen“) / When `PhoneRule.numbers(in:)` im iOS-27.0-Simulator und auf
  dem Mac-Ziel läuft / Then ist das Ergebnis auf beiden leer, und `PhoneRule` ruft weder `NoteLinks` noch `NSDataDetector` noch ein
  Regex, sondern scannt `Character` mit ASCII-Ziffern. Nachweis: Unit-Test in beiden Zielen (iOS-Simulator lokal, Mac-Job der CI);
  Durchsicht des Diffs.
  - Test: LooseEndsTests/PhoneRuleTests.swift::detectorOnlyDigitRunsAreIgnored
- **AC-6:** Notiz und Titel im Produktablauf (Regelschritt): Given eine neue Aufgabe mit „Ruf 040 1234567 an“ bzw. „Die Police
  30021988 umschreiben lassen“, Modell aus / When der Regelschritt läuft / Then bekommt die erste die Notiz „040 1234567“ (Herkunft
  `rule`, Begründung `PhoneRule.reason`) und einen Titel ohne Nummer, die zweite behält die Zahl im Titel und hat keine Notiz.
  Nachweis: Unit-Test (Erweiterung von `ruleStepWritesNote`) und die zwei UI-Smoke-Tests `testPhoneNumberGoesToNoteNotTitle` und
  `testPolicyNumberStaysInTitleAndNoteStaysEmpty` per `./scripts/sim.sh test-proof CaptureSmokeTests`.
  - Test: LooseEndsTests/PhoneRuleTests.swift::ruleStepWritesNote, LooseEndsTests/PhoneRuleTests.swift::ruleStepLeavesPolicyNumberAlone, LooseEndsUITests/CaptureSmokeTests.swift::testPhoneNumberGoesToNoteNotTitle, LooseEndsUITests/CaptureSmokeTests.swift::testPolicyNumberStaysInTitleAndNoteStaysEmpty
- **AC-7:** Nichts sonst und alles grün: Given der Diff / When er geprüft wird / Then berührt er nur `PhoneRule.swift`,
  `PhoneRuleTests.swift`, `CaptureSmokeTests.swift` und den Kommentar in `NoteLinks.swift`; `EnrichmentCoordinator.swift`,
  `rule-golden.json`, `project.yml`, Info.plist und Entitlements bleiben unverändert; voller `sim-unit`-Lauf grün und der Mac-Job
  „Unit Tests (macOS destination)“ der CI grün. Nachweis: `git diff --stat`, voller Lauf als Beleg (Swift Testing, siehe Test Plan),
  CI.
  - Test: voller Lauf `./scripts/sim.sh sim-unit` (alle Suiten)

## Dependencies

| Komponente | Beschreibung |
|---|---|
| `NoteLinks` | bisher Quelle der Treffer (`NoteLinks.hits`); danach keine Abhängigkeit mehr, nur ein Kommentar |
| `TitleRule.title` | ruft `PhoneRule.removing`; Verhalten ändert sich nur durch die Regel |
| `EnrichmentCoordinator.applyPhoneRule` | ruft `PhoneRule.note`; unverändert |
| `RuleGoldenTests`, `rule-golden.json` | Beleg für die Gleichheit auf iOS und Mac |

Keine neue Abhängigkeit.

## Risiken

- **Echte Nummer geht verloren (mittel, abgefedert):** Die Positivtabelle deckt die Formen ab, die beide Detector-Läufe führen; der
  Prototyp trifft auf 651 Korpussätzen exakt dieselben Treffer wie der Mac-Detector. Ein Format außerhalb von DE und NANP wird
  nicht erkannt und bleibt im Titel, ein sichtbarer, harmloser Rückfall.
- **Fehlalarm bleibt (niedrig):** Mehrgruppige Ziffernfolgen mit führender 0 („0815 4711 1234“) gelten als Nummer, wie schon beim
  Detector.
- **UI-Test-Takt (niedrig):** Der Regelschritt läuft nach dem Erfassen; die UI-Tests warten auf `noteText`/Titelwert mit
  Zeitgrenze.
- **Anzeige-Links uneinheitlich (niedrig, benannt):** `NoteLinks` zeigt auf iOS eine reine Ziffernfolge weiter als antippbar; siehe
  Alternative A.

## Alternativen

- **A: `NoteLinks` (Anzeige-Links) ebenfalls auf `PhoneRule` umstellen.** Einheitlich auf allen Geräten, verliert aber Formate, die
  nur der Detector kennt, und hat einen anderen Zweck (Anzeige statt Erfassung). Eigenes Ticket, falls Henning einheitliche Links
  will. Gekippt würde dafür die Wahl aus #439 „die Notiz nutzt dieselbe Regel für Links und Erfassung“.
- **B: Nur die Fixture auf das iOS-Ergebnis setzen.** Verworfen: das Mac-Ziel würde rot, die Geräte blieben uneinheitlich, und auf
  dem iPhone verschwänden Policen- und Kundennummern weiter aus dem Titel.
- **C: Nummernformen ins `LanguagePack`.** Verworfen: dort gibt es keinen Platz für Formate, und für zwei Formen (DE, NANP) wäre es
  übertrieben. Eine Nummernform ist Zahlformat, keine Wortliste.
- **Vorschlag statt automatisch:** die App schlägt die Nummer als Notiz vor und der Nutzer bestätigt. Verworfen: Henning wollte
  „automatisch in die Notiz“ (#439, 2026-10-15); jede Aufgabe bekäme zusätzliche Arbeit.
- **Regex statt Scanner:** kürzer, aber `\d` ist in Swift-Regex Unicode-weit und liefert keine direkten `String.Index`-Ranges für die
  Titelbereinigung. Verworfen.

Gekippt wird keine ADR; nur die Wahl aus #439 „`NSDataDetector` findet sie“ für die Erfassung.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Grund: reine Fehlerbehebung in einer Regel (Detector durch eigenen Scanner ersetzt), keine
  Architekturentscheidung
- **Rationale:** Das Muster „eigener Parser statt Detector“ gilt seit #148 (`DateExpressionParser`, `TimeExpressionParser`); dieser Fix wendet es auf Telefonnummern an.

## Known Limitations

- Der verbleibende Fehlalarm „0815 4711 1234“ (mehrgruppige Ziffernfolge mit führender 0) gilt als Nummer, wie schon beim Detector.
- „2025-0042“ ist dann keine Nummer mehr (Verbesserung gegenüber dem Detector, der sie auf beiden Plattformen meldete).
- Formate außerhalb von DE und NANP (z. B. 3-3-3 ohne führende 0 oder „+“) bleiben im Titel.
- Anzeige-Links in der Notiz folgen weiter dem Detector und können auf iOS eine reine Ziffernfolge als antippbar zeigen.
- Das QA-Gate zählt Swift Testing nicht im Einzellauf; Beleg ist der volle `sim-unit`-Lauf.

## Definition of Done

- [ ] AC-1 bis AC-7 erfüllt; `PhoneRuleTests` und `RuleGoldenTests` grün im iOS-27.0-Simulator, voller `sim-unit`-Lauf grün,
  Mac-Job der CI grün.
- [ ] Simulator-Durchlauf (`test-proof CaptureSmokeTests`, Belege und Screenshots geöffnet und beschrieben).
- [ ] Kein Pfad der Geräteliste berührt; Abnahme endet nach Stufe 2, im Abschlussbericht mit genau diesem Satz.
- [ ] Der PR verweist mit `Closes #786`.
- [ ] Abschlussbericht ohne Git-Vokabular: Policen-, Kunden- und Auftragsnummern bleiben im Titel, echte Telefonnummern gehen wie
  bisher in die Notiz, auf iPhone, iPad und Mac gleich; Henning muss nichts tun.

## Changelog

- 2026-11-01: Initiale Spec für #786: eigener Scanner statt `NSDataDetector` in `PhoneRule`, Positiv-/Negativtabelle, zwei
  UI-Smoke-Tests, Anzeige-Links bleiben beim Detector (Alternative A als eigenes Ticket nur auf Wunsch).
