# Regelspalte nach Textform (#70)

Messung der Regeln (Datum, Uhrzeit, Wichtigkeit, Dringlichkeit, Kontexte, Titel) auf demselben
Inhalt in fünf Formen. Korpus: `Measurement/textform-corpus.json`, 40 Inhalte. Bericht:
`TextFormRuleReportTests`, Referenztag 2026-10-07. Die Modellspalte fehlt noch (iPhone-Laborlauf).

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
