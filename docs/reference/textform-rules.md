# Regelspalte nach Textform (#70)

Messung der Regeln (Datum, Uhrzeit, Wichtigkeit, Dringlichkeit, Kontexte, Titel) auf demselben
Inhalt in fünf Formen. Korpus: `Measurement/textform-corpus.json`, 40 Inhalte. Bericht:
`TextFormRuleReportTests`, Referenztag 2026-10-07.

**Stand 2026-10-25: Die Modellspalte wird bewusst nicht gemessen.** Gründe:

1. Das Modell schreibt im Produkt nur Titelverfeinerung und Dauer (`EnrichmentWriter`; Kontexte nie, #215;
   Projekt nie, #469). Datum, Uhrzeit, Wichtigkeit, Dringlichkeit und Kontexte kommen aus Regeln.
2. Der Mail-Körper erreicht weder Modell noch Regeln, nur der Betreff (`SharedContent.subject(ofMail:)`).
   Der Test `SharedContentTests.mailBodyNeverPrefilled` hält diesen Produktpfad fest.
3. Die Titel-Regel (`TitleRule`, #202) hält die Schlüsselwörter in allen Formen zu 100 %.
4. Der Korpus hat keine Wahrheit für die Dauer; eine Modellmessung wäre nur Selbstkonsistenz Form gegen Form.

Die Formtreue des Modells für Titel und Dauer wird als Spalte im Laborlauf von #88 gemessen. Der Lauf
braucht Hennings wörtliches „jetzt ist ein Test möglich“.

**Ohne Modell geht es nicht, weil …** für kein Feld belegt:

- **Titel:** Die Regel hält die Schlüsselwörter in allen Formen zu 100 % (Tabelle unten).
- **Dauer:** Offen ist sie nur dort, wo der Text keine Länge nennt. Das ist die Frage von #88 und #72,
  nicht der Textform.

Deshalb ist der Regelweg der Vorschlag.

**Modellspalte (#88):** Die Labor-App liest den Korpus direkt und macht aus jedem Inhalt drei Notizen
(`typed`, `dictated`, `english`; der Mail-Körper bleibt draußen, das Produkt reicht nur den Betreff weiter).
Aufruf: `--corpus textform-corpus --runs <n> --result textform-run`, danach `sim.sh lab-fetch`; die
Auswertung ist `TextFormModelReportTests` (ohne Ergebnisdatei laut übersprungen). Lesart: Titel = Anteil der
Notizen, deren Titel alle Schlüsselwörter trägt, die Regelspalte (`TitleRule`) steht daneben, fehlgeschlagene
Aufrufe zählen als verfehlt und werden ausgewiesen; Dauer = Übereinstimmung von `dictated` und `english` mit
`typed`, keine Wahrheit und keine Trefferquote. Der Lauf auf dem iPhone läuft nur nach Hennings
ausdrücklichem „jetzt ist ein Test möglich“.

## Treffer gegen die Wahrheit (richtig / verpasst / falsch / erfunden)

| Feld | typed | dictated | mail | mailCut | english |
|---|---|---|---|---|---|
| Tag | 40 / 0 / 0 / 0 | 39 / 1 / 0 / 0 | 20 / 0 / 0 / 20 | 40 / 0 / 0 / 0 | 40 / 0 / 0 / 0 |
| Uhrzeit | 40 / 0 / 0 / 0 | 39 / 0 / 1 / 0 | 10 / 0 / 0 / 30 | 40 / 0 / 0 / 0 | 40 / 0 / 0 / 0 |
| Wichtigkeit | 40 / 0 / 0 / 0 | 40 / 0 / 0 / 0 | 5 / 0 / 0 / 35 | 40 / 0 / 0 / 0 | 40 / 0 / 0 / 0 |
| Dringlichkeit | 40 / 0 / 0 / 0 | 40 / 0 / 0 / 0 | 11 / 0 / 0 / 29 | 40 / 0 / 0 / 0 | 38 / 2 / 0 / 0 |
| Kontexte | 40 / 0 / 0 / 0 | 40 / 0 / 0 / 0 | 2 / 0 / 13 / 25 | 37 / 3 / 0 / 0 | 37 / 1 / 1 / 1 |

Titel: Schlüsselwörter in allen Formen zu 100 % im Titel; in `mail` beginnen alle 40 Titel mit „Hallo“,
in `mailCut` keiner.

## Diktat nach Zahlenform

| Zahlenform | Inhalte | Tag richtig | Uhrzeit richtig |
|---|---|---|---|
| Ziffern | 7 | 7 | 6 |
| ausgeschriebene Zahlen | 6 | 5 | 6 |
| keine | 27 | 27 | 27 |

## Entscheidung je Kanal

- **Getippt:** Regeln tragen alles (40/40 in allen Feldern). Kein Modell nötig.
- **Diktat:** Regeln tragen alles. Ausgeschriebene Uhrzeiten („um neunzehn Uhr“) fehlten zuerst (2 von 6);
  der `TimeExpressionParser` kennt sie seit dem Fix zu #70 (Uhrzeit 39/40, 6 von 6 bei ausgeschriebenen Zahlen,
  Stand vor dem Fix: 35/40). Ein Fehlgriff bleibt bei einer Ziffernform.
- **Mail (ganzer Text):** Nicht an die Regeln geben. Grußformel, Signatur und Rechtstext erzeugen
  erfundene Felder (Tag 20, Uhrzeit 30, Wichtigkeit 35, Dringlichkeit 29, Kontexte 25 erfunden und 13 falsch;
  „Webseite“ im Datenschutzhinweis ergibt „Computer“ bei allen 40).
- **Mail (zugeschnitten):** Auf den eigenen Text gekürzt gibt es 0 erfundene Felder. Die Share-Erweiterung
  reicht heute nur den Betreff weiter; ein Körper muss vorher zugeschnitten werden, nicht roh.
- **Englisch:** wie getippt (Dringlichkeit 38/40, Kontexte 37/40).

Festlegung (Stand 2026-10-25):

- **Getippt:** roh an die Regeln.
- **Diktat:** roh an die Regeln. Eine Diktat-Normalisierung ist nicht nötig.
- **Englisch:** roh an die Regeln.
- **Mail:** nur Betreff (Produktpfad, `SharedContent.subject(ofMail:)`). Der Körper geht nie roh weiter.
  Kommt je ein Körper-Feature (#342 Teil 5, Epic #371), wird er zuerst auf den eigenen Text zugeschnitten
  (Regelspalte `mailCut`: 0 erfunden).

Das Diktat des Korpus ist geschrieben, nicht gesprochen; die Spracherkennung selbst ist nicht gemessen.
