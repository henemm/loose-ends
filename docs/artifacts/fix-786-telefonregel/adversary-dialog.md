# Adversary Dialog — fix-786-telefonregel
Spec: docs/specs/fix-786-telefonregel.md
Datum: 2026-11-01 20:29

## Checkliste
- [x] **Input:** diktierter oder getippter Satz.
- [x] **Output:** `PhoneRule.ranges` meldet genau die Nummern der Positivtabelle; `TitleRule.title` entfernt sie aus dem Titel;
- [x] **Positiv (Soll, Nummer erkannt):**
- [x] **Negativ (Soll, keine Nummer):** `30021988`, `1234567`, `12345678`, `2025-0042`, `01067 Dresden`, `09:14`, `15.03.2026`, `4711`,
- [x] **Range-Grenzen:** „Ruf 040 1234567.“ → Range endet an der „7“; „Ruf 040 1234567, bitte“ → ebenso; „Ruf 040 1234567 -“ → ebenso.
- [x] **Titel:** „Die Police 30021988 umschreiben lassen“ behält die Zahl; „Ruf 040 1234567 an“ → Titel ohne Nummer, Notiz „040 1234567“.
- [x] **Side effects:** keine neuen.
- [x] **AC-1:** Police bleibt im Titel: Given der Satz „Die Police 30021988 umschreiben lassen“ / When `TitleRule.title(from:)` und `PhoneRule.numbers(in:)` laufen (iOS-27.0-Simulator und Mac-Ziel) / Then enthält der Titel „30021988“ und `numbers` ist leer. Nachweis: Unit-Test in `PhoneRuleTests` und `RuleGoldenTests.matchesFixture` grün im iOS-27.0-Simulator (vorher rot mit `de-gemischt-8` und `de-zahl-10`, Fixture unverändert).
- [x] **AC-2:** Echte Nummern werden erkannt: Given jede Form der Positivtabelle (`+49 251 465560`, `0251/465560`, `040 1234567`, `0151 23456789`, `01761234567`, `0176 1234 5678`, `02 51 / 4 65 56`, `040-987654-0`, `040 987654 - 0`, `040 987654–0`, `+49 (0) 251 465560`, `0049 251 465560`, mit U+00A0, mit U+202F, `(555) 123-4567`, `+1 415 555 0123`) in einem Satz / When `PhoneRule.numbers(in:)` läuft / Then liefert es genau diese Nummer als geschrieben. Nachweis: parametrisierter Unit-Test.
- [x] **AC-3:** Keine Fehltreffer: Given jede Form der Negativtabelle (`30021988`, `1234567`, `12345678`, `2025-0042`, `01067 Dresden`, `09:14`, `15.03.2026`, `4711`, IBAN, „7 Kartons“, „20 Minuten“, `0251.465560`) / When `PhoneRule.numbers(in:)` läuft / Then ist das Ergebnis leer. Nachweis: parametrisierter Unit-Test.
- [x] **AC-4:** Range-Grenzen: Given „Ruf 040 1234567.“, „Ruf 040 1234567, bitte“ und „Ruf 040 1234567 -“ / When `PhoneRule.ranges(in:)` und `removing(from:)` laufen / Then endet jede Range an der letzten Ziffer; Punkt, Komma, Trenner und Leerzeichen am Ende gehören nicht dazu und bleiben im Rest des Satzes. Nachweis: Unit-Test.
- [x] **AC-5:** Unabhängig vom Detector: Given die Sätze, in denen nur der iOS-Detector eine Nummer meldet („Kunde 1234567 anrufen“, „Auftrag 12345678 prüfen“, „Die Police 30021988 umschreiben lassen“) / When `PhoneRule.numbers(in:)` im iOS-27.0-Simulator und auf dem Mac-Ziel läuft / Then ist das Ergebnis auf beiden leer, und `PhoneRule` ruft weder `NoteLinks` noch `NSDataDetector` noch ein Regex, sondern scannt `Character` mit ASCII-Ziffern. Nachweis: Unit-Test in beiden Zielen (iOS-Simulator lokal, Mac-Job der CI); Durchsicht des Diffs.
- [x] **AC-6:** Notiz und Titel im Produktablauf (Regelschritt): Given eine neue Aufgabe mit „Ruf 040 1234567 an“ bzw. „Die Police 30021988 umschreiben lassen“, Modell aus / When der Regelschritt läuft / Then bekommt die erste die Notiz „040 1234567“ (Herkunft `rule`, Begründung `PhoneRule.reason`) und einen Titel ohne Nummer, die zweite behält die Zahl im Titel und hat keine Notiz. Nachweis: Unit-Test (Erweiterung von `ruleStepWritesNote`) und die zwei UI-Smoke-Tests `testPhoneNumberGoesToNoteNotTitle` und `testPolicyNumberStaysInTitleAndNoteStaysEmpty` per `./scripts/sim.sh test-proof CaptureSmokeTests`.
- [x] **AC-7:** Nichts sonst und alles grün: Given der Diff / When er geprüft wird / Then berührt er nur `PhoneRule.swift`, `PhoneRuleTests.swift`, `CaptureSmokeTests.swift` und den Kommentar in `NoteLinks.swift`; `EnrichmentCoordinator.swift`, `rule-golden.json`, `project.yml`, Info.plist und Entitlements bleiben unverändert; voller `sim-unit`-Lauf grün und der Mac-Job „Unit Tests (macOS destination)“ der CI grün. Nachweis: `git diff --stat`, voller Lauf als Beleg (Swift Testing, siehe Test Plan), CI.

## Dialog

### Runde 1
**Adversary:** Lauf `./scripts/sim.sh sim-unit PhoneRuleTests` und `PhoneRuleScannerTests` (iOS-27.0-Simulator), Ausgabe `docs/artifacts/fix-786-telefonregel/adversary-test-output.txt`: beide Suiten bestanden. Voller Lauf `test-green-output.txt` (Test Succeeded, Suites "Phone rule" und "Phone rule without the detector", RuleGoldenTests "Goldene Regelausgabe" bestanden; 3 von 6 Messstrecken und die Sprach-Latenztests übersprungen wegen fehlender Rohdaten bzw. Sprachmodell, keine davon betrifft PhoneRule). UI: `test-green-ui.txt` 26/26.
Code gelesen: Code reference: Shared/Enrichment/PhoneRule.swift:18 (ranges, Character-Scan, ASCII-Ziffern über `isASCII && isNumber`, Zeile 119-121), kein `NoteLinks`/`NSDataDetector`/Regex im Code (grep: nur Doc-Kommentar Zeile 4) -> AC-5 Code-Teil belegt. Code reference: Shared/Services/NoteLinks.swift:5 (nur Kommentarsatz, +2 Zeilen). Code reference: LooseEndsTests/PhoneRuleTests.swift:57 (Positiv-/Negativtabelle, Range, Titel, Regelschritt). Code reference: LooseEndsUITests/CaptureSmokeTests.swift:1080 und :1094 (beide Smoke-Tests).
Randfälle mit Wegwerf-Kopie der Funktion (Scratchpad, `swift`, kein App-Testlauf), 90 Eingaben: "", "+", "(", "0", "(123" -> keine Nummer, kein Absturz. "Ruf 040 1234567." / ", bitte" / " -" -> Range endet an "7", Rest "Ruf ." / "Ruf  -". 16 Ziffern "1234567890123456", 17 Ziffern mit 0, "0123456789012345" (16) -> keine. "Rechnung2025-0042", "Nr0251465560", "Rechnung 2025-0042" -> keine. Zwei Nummern -> beide in Reihenfolge. Emoji vor der Nummer -> Nummer gefunden, Index-Mapping korrekt. Zerlegtes "e"+U+0301 direkt davor -> nicht frei (isLetter), keine Nummer, richtig. Arabisch-indische Ziffer und Vollbreite-Ziffern zählen nicht. IBAN -> keine Teilnummer. "0251 465560x" -> Nummer ohne x. Ergebnis: alle Tabellen-ACs halten.
Abweichungen: (1) Lauf überspringen statt ein Zeichen weiter: nötig, weil sonst die IBAN-Reste "0044 0532 0130 00" als Nummer zählten (AC-3). Kosten gemessen: "3 0151 23456789" und "0251 465560 - 0176 1234 5678" (17 Ziffern, beide verloren) liefern nichts; der Mac-Detector meldet bei letzterem "0251 465560 – 0176" und "1234 5678" (auch fehlerhaft), also kein klarer Verlust, kein AC verletzt. (2) dritter Parameter `opened:` trägt die Regel "0/+/( + Ziffer" aus Regel 1; Spec nennt `isValid(digits:groups:)`, nur Signatur, kein AC. (3) Klammergruppe überall: "0251 (465560)" harmlos, "a(0251) 465560" bleibt wegen Frei-Prüfung keine Nummer; kein AC verletzt.
Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: Shared/Enrichment/PhoneRule.swift:84
  Description: `isValid` nimmt jede mit "0" beginnende Gruppenfolge mit 7-15 Ziffern, auch Daten mit Schrägstrich oder Bindestrich. "Termin 01/02/2026" -> Nummer "01/02/2026", Titel "Termin ", Notiz "01/02/2026"; "05-03-2026 bis 07-03-2026" -> beide als Nummern. Der Mac-NSDataDetector meldet diese Fälle nicht (selbst geprüft), Punktdaten ("15.03.2026") sind wegen Regel 7 sicher.
  Spec requirement: Expected Behavior Negativ / Known Limitations - Titel und Notiz sollen wie beim Mac-Detector ausfallen; Datumsformen nur mit Punkt geprüft
  Conflict: Keine Tabellenzeile verletzt (kein AC gebrochen), aber neue Fehltreffer gegenüber dem Mac-Detector, die die Spec nicht als Limitation nennt (nur "0815 4711 1234").
  Remediation: Entweder als Known Limitation in die Spec aufnehmen oder Daten 2-2-4 mit "/" bzw. "-" ausschließen; eigenes Ticket genügt.
**Implementierer:** (keine Antwort in diesem Lauf)

### Runde 2
**Adversary:** Zweiter Durchgang. Rest-Risiken: Character- statt Skalar-Indizes und Ende-Prüfung. Gemessen: "0251 465560" + U+0301 (Kombinationszeichen an der letzten Ziffer) -> Range "0251 46556", Rest "0́". Kein Absturz, Range liegt auf Character-Grenzen, in diktiertem Text praktisch nie.
Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: Shared/Enrichment/PhoneRule.swift:120
  Description: `isDigit` verlangt `char.isASCII`; eine Ziffer mit Kombinationszeichen ist ein Nicht-ASCII-Character und beendet die Nummer eine Ziffer zu früh ("0251 465560" + U+0301 -> "0251 46556").
  Spec requirement: Scanner-Regel 6 - Ende nach der letzten Ziffer
  Conflict: Nur bei Kombinationszeichen nach einer Ziffer, keine Tabellenzeile betroffen.
  Remediation: Ignorierbar oder über `unicodeScalars` prüfen.
Weiter geprüft: Text endet mit Trenner ("0251-", "0251 465560-", "... –", "... / ") -> Trenner bleiben im Rest. Zeilenumbruch zwischen Gruppen -> keine Nummer (Spec: nur U+0020/00A0/202F), richtig. Nummer am Satzanfang/-ende, "Tel:0251 465560" -> gefunden. "++49 ..." und "+ 49 ..." -> keine. Funktionslängen alle unter 50 Zeilen.
Diff-Umfang (AC-7): Dateien seit a065089 ohne docs: nur PhoneRuleTests.swift, CaptureSmokeTests.swift (RED-Commit) plus im Arbeitsbaum PhoneRule.swift und NoteLinks.swift (Kommentar); Koordinator, rule-golden.json, project.yml, Info.plist, Entitlements unberührt. Code reference: Shared/Enrichment/PhoneRule.swift:4
Mac-Teil AC-5/AC-7: lokal nicht belegbar (Mac-Ziel läuft nur im CI-Job "Unit Tests (macOS destination)" nach dem Push). Indirekt gestützt: der Scanner nutzt nur Swift-Standard (Character, String.Index), keine Plattform-API. Mac-Teil bleibt formal OFFEN bis der CI-Job grün ist (Merge-Bedingung).
**Implementierer:** (keine Antwort in diesem Lauf)

### Runde 3
**Adversary:** Nachprüfung nach dem Fix von F001. Frischer Lauf `./scripts/sim.sh sim-unit PhoneRuleScannerTests` (`adversary-test-output.txt`): Suite "Phone rule without the detector" bestanden, Test Succeeded. Code gelesen: Code reference: Shared/Enrichment/PhoneRule.swift:83 (`isValid`: drei Gruppen 1-2/1-2/4 -> false, vor der Längenregel). Code reference: Shared/Services/NoteLinks.swift:5 (unverändert, nur Kommentar). Code reference: LooseEndsTests/PhoneRuleTests.swift:57 (Suite mit slashedDatesAreIgnored und slashedDateStaysInTitle). Code reference: LooseEndsUITests/CaptureSmokeTests.swift:1080 (UI 26/26 laut test-green-ui.txt).
Wegwerf-Skript (Kopie der Funktion), Vergleich mit Mac-NSDataDetector:
- F001-Fälle behoben: "Termin 01/02/2026", "Termin 01-02-2026", "05-03-2026 bis 07-03-2026", "01/02/2026 - 03/04/2026" -> keine Nummer, Titel unversehrt.
- Alle Positivformen weiter erkannt ("+49 251 465560", "0251/465560", "040 987654-0", "(555) 123-4567", "+1 415 555 0123").
- Verlust echter Nummern mit Gruppen 1-2/1-2/4: "01 23 4567", "02 51 4565", "+49 30 1234", "+1 23 4567" -> keine Nummer; der Detector meldet alle vier. "+49 30 123456" bleibt erkannt (Gruppen 2/2/6).
- Datum plus Uhrzeit: "01/02/2026 10:30" -> Treffer "01/02/2026 10" (Gruppen 2/2/4/2 = 10 Ziffern), Rest ":30"; der Detector meldet nichts. "01/02/26 12" -> Treffer.
Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: Shared/Enrichment/PhoneRule.swift:83
  Description: Reine Datumsform mit "/" oder "-" ist behoben (siehe oben). Status: behoben für die gemeldeten Fälle, teilweise offen für Datum plus Uhrzeit (F004).
  Spec requirement: Negativ-Tabelle (Datumsformen), Parität zum Mac-Detector
  Conflict: aufgelöst für 3-Gruppen-Daten.
  Remediation: keine mehr für den Kern.
Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: Shared/Enrichment/PhoneRule.swift:84
  Description: Die Datumsregel trifft auch echte kurze Nummern der Form 1-2/1-2/4 Ziffern: "Ruf 01 23 4567 an" und "+49 30 1234" ergeben keine Nummer (bleiben im Titel). Der Detector findet beide.
  Spec requirement: Positiv-Semantik der Scanner-Regeln 1 und 5 (7-15 Ziffern, "+"/"0" öffnet)
  Conflict: Keine Positivtabelle betroffen; ein "+"- oder "0"-geöffnetes Muster wird verworfen.
  Remediation: Datumsregel nur bei Trenner "/" oder "-" und ohne öffnendes "+"; Leerzeichen-Trenner nicht verwerfen.
Finding:
  ID: F004
  Severity: MEDIUM
  Category: edge_case
  Code reference: Shared/Enrichment/PhoneRule.swift:83
  Description: Datum mit Uhrzeit: "01/02/2026 10:30" -> Nummer "01/02/2026 10", Titel behält ":30". Die Datumsregel greift nur bei genau drei Gruppen; die Uhrzeitziffern machen eine vierte daraus.
  Spec requirement: Negativ-Tabelle, Parität zum Mac-Detector
  Conflict: Kein AC verletzt (Tabellen grün), aber derselbe Fehlertyp wie F001 in kombinierter Form.
  Remediation: Datum 1-2/1-2/4 am Anfang einer Folge verwerfen, egal ob weitere Gruppen folgen, oder Folge hinter einem Datum nicht fortsetzen.
Weiteres: keine AC ist betroffen; Mac-Teil AC-5/AC-7 weiter offen bis der CI-Job grün ist.
**Implementierer:** (keine Antwort in diesem Lauf)

### Runde 4
**Adversary:** Nachprüfung von F003/F004. Frischer Lauf `./scripts/sim.sh sim-unit PhoneRuleScannerTests` (`adversary-test-output.txt`): Suite "Phone rule without the detector" bestanden, Test Succeeded. Code reference: Shared/Enrichment/PhoneRule.swift:89 (`isDateShaped`: erste drei Gruppen 1-2/1-2/2 oder 4 Ziffern, beide Trenner identisch "/" oder "-" ohne Leerzeichen; `isValid` ohne Datumszeile). Code reference: Shared/Services/NoteLinks.swift:5 (unverändert, Kommentar). Code reference: LooseEndsTests/PhoneRuleTests.swift:57 (Suite, erweiterte Datums- und Kurznummerntests). Code reference: LooseEndsUITests/CaptureSmokeTests.swift:1080 (UI 26/26 laut test-green-ui.txt).
Wegwerf-Skript (Kopie), 37 Eingaben, Vergleich mit Mac-Detector:
- F001 behoben: "Termin 01/02/2026", "Termin 01-02-2026", "05-03-2026 bis 07-03-2026", "1/2/2026", "12/12/12" -> keine Nummer.
- F004 behoben: "01/02/2026 10:30" und "01/02/26 12 Uhr" -> keine Nummer (Detector ebenfalls nicht).
- F003 behoben: "01 23 4567", "02 51 4565", "+49 30 1234" -> Nummer gefunden. "Ruf 0251 465560 und 01/02/2026" -> nur die Nummer. "0151 23456789 am 01/02/2026" -> nur die Nummer. Daten nach Komma getrennt von einer Nummer ("01/02/2026, 0151 23456789") -> Nummer bleibt.
- Positivformen unverändert erkannt: "040-987654-0" (3/6/1, kein Datum), "040 987654 - 0", "0251/465560", "0176 1234 5678", "02 51 / 4 65 56", "+49 (0) 251 465560", "(555) 123-4567", "+1 415 555 0123". IBAN und "30021988" -> keine.
- Bewertung "02-51-4565": gilt jetzt als Datum (2/2/4 mit "-"), keine Nummer. Gleiches gilt für "01-23-4567" und "01-23-45-67-89". Der Detector meldet diese drei als Nummer. Kompromiss der Datumsregel (05-03-2026 ist gleichgeformt); kein AC betroffen.
Finding:
  ID: F005
  Severity: LOW
  Category: edge_case
  Code reference: Shared/Enrichment/PhoneRule.swift:89
  Description: Nummern mit "-" in der Form 1-2/1-2/2-4 ("02-51-4565", "01-23-4567", "01-23-45-67-89") werden als Datum behandelt und bleiben im Titel. Ebenso verliert "040 1234567 -12-2026" die ganze Folge samt "040 1234567"; "01/02/2026 0151 23456789" (Datum direkt vor Nummer mit Leerzeichen) verliert die Nummer.
  Spec requirement: Scanner-Regel 3 (Trenner) und Regel 8 (Lauf überspringen)
  Conflict: Seltene Formen; unvermeidbarer Zielkonflikt zwischen "05-03-2026" (Datum) und "02-51-4565" (Nummer). Keine Tabellenzeile betroffen.
  Remediation: Als Known Limitation in die Spec aufnehmen.
Findings-Status: F001 behoben, F002 LOW unverändert (ignorierbar), F003 behoben, F004 behoben, F005 LOW offen (dokumentieren). Mac-Teil von AC-5/AC-7 weiter offen bis der CI-Job grün ist.
**Implementierer:** (keine Antwort in diesem Lauf)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

Confirmation:
  AC: AC-1, AC-2, AC-3, AC-4, AC-6
  Code reference: Shared/Enrichment/PhoneRule.swift:37
  Evidence: Police-Satz ergibt keine Range (opened=false, nicht 3-3-4); Tabellen, Range-Grenzen, Regelschritt und beide UI-Tests bestanden.
  Status: CONFIRMED

Confirmation:
  AC: AC-5, AC-7
  Code reference: Shared/Services/NoteLinks.swift:6
  Evidence: nur Kommentar geändert; PhoneRule ohne Detector/Regex; Mac-CI-Job offen.
  Status: CONFIRMED

Confirmation:
  AC: AC-2, AC-3
  Code reference: LooseEndsTests/PhoneRuleTests.swift:69
  Evidence: parametrisierte Positiv-/Negativtests und Regelschritt-Tests grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: LooseEndsUITests/CaptureSmokeTests.swift:1080
  Evidence: UI-Smoke-Tests 26/26 grün (test-green-ui.txt).
  Status: CONFIRMED

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:9fb2556f27bbbee1f113d2021ab797ff91dd9e253bc9565fed1284485dac90fc  LooseEndsTests/PhoneRuleTests.swift
- sha256:a773a335789277ce45ef93d24de2e9d129c14fb8ee7e2eef5e1bbdf19bd18594  LooseEndsUITests/CaptureSmokeTests.swift
- sha256:2d8ed413e90623b60be98911bafb1f3aa5cafe735a4bca100a086e1da56cdde0  Shared/Enrichment/PhoneRule.swift
- sha256:c6e7c7606a8b7311794205b4bac99d8d21fda6e955107269b88177f89e3ba75c  Shared/Services/NoteLinks.swift

## Prüfbasis

- base: a06508986771be14e93834ae57ddf6bb3ebe8345
- blob:fd1450add639aabc9ec9e67d3944071e22d3aacf  LooseEndsTests/PhoneRuleTests.swift
- blob:1ccce10a28daa91c5ab53e02755e57648ffb5dd6  LooseEndsUITests/CaptureSmokeTests.swift
- blob:f422d8ea6438cc7edc4682f3428f8ff5af26b6c4  Shared/Enrichment/PhoneRule.swift
- blob:57908b251df200fd6fac4e8c29b96e77ee0f3695  Shared/Services/NoteLinks.swift
