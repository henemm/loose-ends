# Korpus-Messung als Nulllinie — #144 (AC-10)

Maschinell erzeugt aus den beiden Lauf-Ausgaben in diesem Ordner. Kein Wert dieser Datei ist von
Hand eingetragen: Testzahlen aus der Zahl der Einzeltest-Haken, Suitenvergleich aus `comm` ueber
beide Ausgaben, Commit-Kennung aus `git rev-parse HEAD`, Berichtsstand aus `git diff`.

- **Letzter Commit beim Messen:** `be53c433c377a7fc650c7a6e1c0bc6668d7fc33e` (die Umsetzung selbst war zu diesem Zeitpunkt noch
  nicht gesichert — der Commit-Zwang haengt am Adversary-Verdict. Den gemessenen Code benennen
  deshalb die Pruefsummen unten, nicht die Commit-Kennung.)
- **Erzeugt:** 2026-09-28T15:24:13Z
- **Korpus:** `docs/reference/focusblox-corpus.json`, 200315 Byte, aus dem Hauptordner kopiert, nicht verschoben (#135)

### Pruefsummen des gemessenen Produktivcodes

| Datei | SHA-256 |
|---|---|
| `Shared/Models/TaskItem.swift` | `2a8b66eb99c1cfc9f0a61a8bd44cab667776b58872e7f12534d5632918d1c3a6` |
| `Shared/Enrichment/EnrichmentCoordinator.swift` | `9df2d1f42664652dd89c01feb38c7152e04c0745e8f897260edf34f47e7b3baf` |
| `Shared/Enrichment/RecognitionRule.swift` | `67d902ae88bf39351973465b5acda426cd090fae3a8f9837a8fe3711cb43d97c` |

`RecognitionRule.swift` steht mit in der Liste, weil die Korpus-Messung genau diese Datei misst.
Sie wurde von #144 nicht angefasst; die Pruefsumme macht das nachrechenbar statt behauptet.

## Zahl ausgefuehrter Tests

| Lauf | Zeitstempel (UTC) | Einzeltests | Suiten | Ergebnis | Ausgabe |
|---|---|---|---|---|---|
| ohne Korpus | 2026-09-28T14:39:08Z | 225 | 44 | Test Succeeded | `test-green-output.txt` |
| mit Korpus | 2026-09-28T15:20:21Z | 229 | 47 | Test Succeeded | `test-green-mit-korpus.txt` |

Die hoehere Zahl im Lauf mit Korpus ist der Beleg fuer „echt gelaufen". Gleiche Zahl hiesse: die
Messstrecke wurde erneut still uebersprungen, und der gruene Lauf sagt ueber sie nichts aus.

### Suiten, die nur mit Korpus liefen

- `FocusBloxCalibrationTests`
- `RecognitionRuleCorpusTests`
- `RuleLeaveOneOutReportTests`

### Suiten, die nur ohne Korpus liefen

- (keine)

## Die vier in der Spec genannten Suiten — Abgleich mit der Wirklichkeit

| Suite laut Spec | ohne Korpus | mit Korpus |
|---|---|---|
| `RecognitionRuleCorpusTests` | nein | lief |
| `RuleLeaveOneOutTests` | nein | nein |
| `FocusBloxCalibrationTests` | nein | lief |
| `SelfConsistencyReportTests` | nein | nein |


**Befund: die Spec nennt zwei Suiten falsch.** Der Abgleich oben ist der Nachweis.

1. `RuleLeaveOneOutTests` ist nicht korpusgegattert — das ist die Logik-Suite
   (`RuleLeaveOneOutTests.swift:57`), sie laeuft immer. Die gegatterte Suite heisst
   `RuleLeaveOneOutReportTests` (Z. 197) und ist im Lauf mit Korpus hinzugekommen.
2. `SelfConsistencyReportTests` haengt an ZWEI Dateien (`SelfConsistencyReportTests.swift:21-22`):
   am Korpus **und** an `docs/reference/selfconsistency-run.json`. Diese zweite Datei existiert
   weder im Arbeitsstand noch im Hauptordner — sie entsteht aus einem Messlauf auf dem Geraet
   (Spike #108). Die Suite kann deshalb derzeit ueberhaupt nicht laufen, mit oder ohne Korpus, und
   sie misst Selbstkonsistenz des Modells, nicht die Wiedererkennung.

Fuer #144 traegt der Abgleich trotzdem: Die fuer diese Aenderung zustaendige Messstrecke
(`RecognitionRuleCorpusTests`) ist von „nein" auf „lief" gewechselt.

## Messzahlen der Wiedererkennung — woertlich aus dem Lauf mit Korpus

```
    Suite RecognitionRuleCorpusTests started
        ✔ "Voller Pool: 61 von 104 Kontext- und 169 von 276 Dauer-Aufgaben, je 100 % richtig (AC-12)" (0.601 seconds)
        ✔ "Entduplizierter Pool: praktisch kein Treffer — es ist Wiedererkennung, keine Ähnlichkeit (AC-12)" (0.134 seconds)
    Suite RecognitionRuleCorpusTests passed after 0.736 seconds
```

Diese Zahlen stehen als feste Erwartungen im Testcode (`RecognitionRuleTests.swift`: 104 Kontext-
und 276 Dauer-Eintraege, 61/61 und 169/169 Treffer, entdupliziert 0/0). Ein gruener Lauf ist
deshalb zugleich der Nachweis, dass sie unveraendert sind — jede Abweichung haette die Suite rot
gemacht. Das ist der staerkere Nachweis als ein Textvergleich zweier Berichte: Die Zahl ist die
Zusicherung selbst, nicht ihre Abschrift.

## Berichtsdateien nach dem Zuruecksetzen

| Berichtsdatei | Stand |
|---|---|
| `docs/reference/date-title-fidelity.md` | auf dem Stand des Repositories |
| `docs/reference/focusblox-calibration-report.md` | auf dem Stand des Repositories |
| `docs/reference/retrieval-leave-one-out-rules.md` | auf dem Stand des Repositories |
| `docs/reference/retrieval-convention-spike.md` | auf dem Stand des Repositories |


Zwei der drei ueberschriebenen Berichte sind ein eigener Befund, nicht von #144 verursacht:

1. `date-title-fidelity.md` enthaelt einen Beispielsatz („Am Freitga den Zaehlerstand melden"),
   dessen erwarteter Termin am heutigen Kalendertag haengt. Der Bericht aendert sich dadurch an
   jedem anderen Tag von allein (NSDataDetector 67.6 % -> 68.3 %), auch ohne Codeaenderung.
   Ein Messbericht, der nicht reproduzierbar ist, taugt nicht als Vergleichsmassstab.
2. `focusblox-calibration-report.md` wurde durch den Lauf **entwertet**: Die eingecheckte Fassung
   stammt von einem Geraetelauf mit Apple Intelligence (uebersprungen: 1), der Lauf hier lief im
   Simulator ohne Modell (uebersprungen: 60) und schrieb vier Tabellen mit lauter Nullen und
   `nan%`. Waere der Bericht mitgegangen, haette #144 eine echte Messung durch Datenmuell ersetzt.
3. `retrieval-leave-one-out-rules.md` aenderte nur den Messtag (2026-09-26 -> 2026-09-28), alle
   Zahlen identisch — eine zusaetzliche, unabhaengige Bestaetigung, dass die Regelzahlen unberuehrt
   sind.

Alle drei sind auf den Stand des Repositories zurueckgesetzt.
