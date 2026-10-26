---
entity_id: spike-70-textform
type: feature
created: 2026-10-25
updated: 2026-10-25
status: draft
workflow: spike-70-textform
---

# Spec: Ist die Textform egal? B2 ohne Modell beantworten (#70)

## Approval

- [ ] Approved

## GitHub Issue

#70 (Epic #370, Meilenstein M3). Annahme B2 in `docs/project/06-annahmen-und-experimente.md`.
Grundlage: `docs/context/spike-70-textform.md` (Befund, Varianten A/B/C), `docs/reference/textform-rules.md` (Regelspalte, PR #270).
Folgearbeit: #88 (Laborlauf, Modell-Formtreue für Titel und Dauer), #342 Teil 5 und Epic #371 (Mail-Körper).

## Purpose

Die Annahme B2 sagt: Derselbe Inhalt soll als getippt, diktiert, Mail und Englisch dieselbe Struktur ergeben. Die Regelspalte ist gemessen (40 Inhalte × 5 Formen).
Offen war die Modellspalte (iPhone-Laborlauf). Die Analyse zeigt, dass sie für das Produkt nichts mehr entscheidet:

- Das Modell schreibt im Produkt nur **Titelverfeinerung und Dauer** (`EnrichmentWriter`, #215 Kontexte nie, #469 Projekt nie). Datum, Uhrzeit, Wichtigkeit, Dringlichkeit und Kontexte kommen aus Regeln.
  Das Abbruchkriterium des Tickets („Felder zwischen getippt und diktiert") betrifft das Modell also nur noch für zwei Felder.
- **Mail:** Der Körper erreicht weder Modell noch Regeln, nur der Betreff (`SharedContent.subject(ofMail:)`). „Mail setzt Felder aus der Signatur" kann im Produkt nicht geschehen.
- **Titel:** Die Regel (`TitleRule`, #202) hält die Schlüsselwörter in allen Formen zu 100 %.
- **Dauer:** Der Textform-Korpus hat keine Wahrheit für Dauer; eine Modellmessung wäre nur Selbstkonsistenz Form gegen Form.

**Regel-Spalte (Nulllinie):** getippt 40/40 in allen Feldern, Diktat 39–40/40, Englisch 37–40/40, Mail zugeschnitten 0 erfunden, Mail roh 0 brauchbar (`textform-rules.md`).

**Ohne Modell geht es nicht, weil** … für kein Feld belegt: Titel Regel 100 % Schlüsselwörter; Dauer nur dort offen, wo der Text keine Länge nennt, und das ist die Frage von #88/#72, nicht der Textform.
Darum ist der Regelweg der Vorschlag.

**Dieses Ticket ändert kein Produktverhalten.** Es schließt den Bericht ab, trägt das Ergebnis in B2 ein und hält den Produktpfad „Mail nur Betreff" in einem Test fest.

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine — Es wird keine Architektur geändert, nur gemessen und eine Annahme (B2) berichtigt; der Produktpfad (Betreff statt Körper, Regeln vor Modell) besteht schon.

Alternativen (aus der Analyse) und was sie kippen würden:

| Variante | Wirkung | Kippt |
|---|---|---|
| **A. B2 ohne Modell beantworten** (gewählt): Regelspalte plus Produktpfad „nur Betreff"; Modell-Formtreue für Titel/Dauer als Spalte im ohnehin nötigen Laborlauf von #88 | Antwortet für alle Felder, die das Produkt setzt; kein Gerät für #70 | Wortlaut der Annahme B2: „das Modell muss aus allen Formen dieselbe Struktur machen" wird zu „die Struktur entsteht aus allen Formen" |
| B. Eigene Modellspalte jetzt (Adapter, ≈ 160 Aufrufe auf dem iPhone, ≈ 25 min) | Zusätzlich Titel/Dauer-Selbstkonsistenz | nichts; kostet Gerätelauf mit Hennings „jetzt ist ein Test möglich", zweites Korpusformat |
| C. Modellspalte endgültig streichen | Am wenigsten Aufwand | zusätzlich: Titelverfeinerung durch das Modell bliebe dauerhaft ungeprüft |

## Source

| Datei | Änderung | LoC (Schätzung) |
|---|---|---|
| `docs/reference/textform-rules.md` | MODIFY: Kopfsatz „Modellspalte fehlt noch" ersetzen durch Befund und Verweis auf #88; Abschnitt „Entscheidung je Kanal" um Produktpfad und Mail-Körper-Regel ergänzen; Zeile „Ohne Modell geht es nicht, weil …" | +30 / −2 |
| `docs/project/06-annahmen-und-experimente.md` | MODIFY: B2 mit Ergebnis (Regelspalte, Produktpfad), berichtigtem Wortlaut und Verweis auf #88; Zeile im Festlegungen-Block (Kanalspezifische Vorverarbeitung) angepasst | +6 / −2 |
| `LooseEndsTests/SharedContentTests.swift` | MODIFY: ein Test, der den Produktpfad festhält: Mail mit langem Körper aus Signatur, Zitat und Rechtstext ergibt `prefill` = Betreff, der Körper erscheint nirgends | +18 |

Drei Dateien, geschätzt +54 / −4 LoC. Produktcode bleibt unverändert. Zusätzlich (außerhalb der Dateizahl): Kommentar an #88 mit der Übergabe (Modell-Formtreue Titel/Dauer als Spalte im Laborlauf) und Kommentar an #70 mit dem Ergebnis.

### Inhalt der Änderungen

- **`textform-rules.md`:** Kopf nennt Stand 2026-10-25 und dass die Modellspalte bewusst nicht gemessen wird (Begründung in vier Sätzen: Modell schreibt nur Titel und Dauer; Mail-Körper erreicht es nie; Titel-Regel 100 %; Dauer ohne Wahrheit im Korpus).
  Entscheidung je Kanal bleibt (getippt, Diktat, Englisch: roh an die Regeln; Mail: nur Betreff, Körper nie roh; kommt je ein Körper-Feature, dann zuerst auf den eigenen Text zuschneiden, Regelspalte mailCut: 0 erfunden) und bekommt die Zeile „Diktat-Normalisierung nicht nötig".
- **`06` B2:** Die Tabellenzeile bekommt die Spalte „Ergebnis": *Entschieden (2026-10-25): die Struktur entsteht aus allen Formen durch Regeln; Abbruchkriterium greift nicht (Diktat 39–40/40, Mail setzt im Produkt nichts); Modell-Formtreue Titel/Dauer in #88.*
- **Test:** Name beschreibt das Verhalten („Mail: nur der Betreff wird vorbelegt, nie der Körper").

## Acceptance Criteria

- **AC-1:** `docs/reference/textform-rules.md` enthält nicht mehr den Satz „Die Modellspalte fehlt noch" und nennt stattdessen, dass die Modellspalte nicht gemessen wird, mit den vier Gründen der Analyse und dem Verweis auf #88.
- **AC-2:** Der Bericht enthält die Zeile „Ohne Modell geht es nicht, weil" mit Beleg je Feld, das das Modell schreibt (Titel, Dauer).
- **AC-3:** Der Abschnitt „Entscheidung je Kanal" nennt für jeden der vier Kanäle (getippt, Diktat, Mail, Englisch) „roh an die Regeln" oder „nur Betreff"; für den Mail-Körper steht, dass er nie roh, sondern nur zugeschnitten weitergegeben wird.
- **AC-4:** `docs/project/06-annahmen-und-experimente.md` trägt in der B2-Zeile das Ergebnis mit Datum, den berichtigten Wortlaut („die Struktur entsteht aus allen Formen") und den Verweis auf #88 für Titel/Dauer-Formtreue des Modells.
- **AC-5:** Ein Unit-Test in `SharedContentTests` übergibt eine Mail mit Betreff und einem Körper aus Gruß, Signatur, Zitat und Rechtstext; `prefill` ist genau der Betreff, und der Körpertext kommt in `prefill` nicht vor. Der Test läuft grün im Simulator (`sim.sh sim-unit SharedContentTests`).
- **AC-6:** Alle bisherigen Tests von `SharedContentTests` und `TextFormRuleReportTests` bleiben grün; `TextFormRuleReportTests` erzeugt den Bericht unverändert (die Zahlen im Bericht stimmen mit der Ausgabe überein).
- **AC-7:** Auf #88 liegt ein Kommentar, der die Übergabe nennt (Modell-Formtreue für Titel und Dauer als Spalte im Laborlauf, Gerätefreigabe wörtlich nötig); auf #70 liegt das Ergebnis, und #70 wird mit dem PR geschlossen.
- **AC-8:** Es wird kein Gerät von Henning angefasst; der Abschlussbericht enthält den Satz „Kein Pfad der Geräteliste berührt."

## Test Plan

| Test | Art | Beweist |
|---|---|---|
| `SharedContentTests` – neuer Fall „Mail: nur der Betreff wird vorbelegt, nie der Körper" | Unit (Simulator) | AC-5: der Produktpfad, auf den B2 sich stützt, ist festgehalten und bricht bei einer Änderung |
| `TextFormRuleReportTests` (vorhanden) | Unit | AC-6: Regelspalte unverändert, Zahlen im Bericht belegt |
| Lesen/`grep` der zwei Dokumente | Prüfung | AC-1 bis AC-4 |

Der Test wird zuerst geschrieben und muss beweisen, dass er etwas prüft: Gegenprobe, indem `prefill` kurzzeitig auf den Körper gelegt wird, muss ihn rot machen (im Worktree, nicht eingecheckt).

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `SharedContent.subject(ofMail:)`, `SharedContent.make(…)` (`Shared/Services/SharedContent.swift`) | wird getestet, nicht geändert |
| `Measurement/textform-corpus.json`, `TextFormRuleReportTests` | Quelle der Zahlen, nicht geändert |
| #88 (Messkorpus, Laborlauf) | bekommt die Übergabe für Titel/Dauer-Formtreue |
| #342 Teil 5, Epic #371 | nutzen die Kanalentscheidung zum Mail-Körper |

## Scope

Siehe Tabelle unter „Source" (Dateien und LoC). Risiken:

- 3 Dateien, ±58 LoC, nur Doku und ein Test; Risiko niedrig.
- Keine neuen Permissions, keine Schlüssel, keine Audio-Dateien, kein Schema.
- Offene Wirkung: Die Titelverfeinerung durch das Modell bleibt bis #88 ungeprüft (Risiko, nicht neu).
- Das Diktat des Korpus ist geschrieben, nicht gesprochen; die Spracherkennung selbst ist nicht Teil der Messung (steht im Bericht).

## Definition of Done

- [ ] AC-1 bis AC-4: `textform-rules.md` und B2 in `06` sind berichtigt und belegt
- [ ] AC-5: neuer Test in `SharedContentTests` ist grün und fällt bei der Gegenprobe rot aus
- [ ] AC-6: `SharedContentTests` und `TextFormRuleReportTests` vollständig grün
- [ ] AC-7: Kommentar auf #88, Ergebnis auf #70, #70 per PR geschlossen
- [ ] AC-8: Abschlussbericht mit „Kein Pfad der Geräteliste berührt."

## Changelog

- 2026-10-25: Initiale Fassung (Variante A der Analyse: B2 ohne Modell beantworten)
