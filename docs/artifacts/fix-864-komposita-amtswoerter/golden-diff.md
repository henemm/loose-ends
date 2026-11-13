# Golden-Diff #864 — Begründung je Zeile

Erneuert mit `LOOSEENDS_UPDATE_GOLDEN=1 ./scripts/sim.sh sim-unit RuleGoldenTests`. Der Simulator (iOS 27.2) schreibt
`"key" : "wert"` statt `"key": "wert"`; die Datei wurde auf die bisherige Schreibweise zurückgeformt (nur Leerzeichen vor
dem Doppelpunkt, abschließender Zeilenumbruch wiederhergestellt), damit der Diff nur die inhaltlichen Zeilen zeigt.
`git diff --stat`: 5 Einfügungen, 5 Löschungen.

Zeilen mit `"importance": "high"`: vorher 96, nachher 101. Alle fünf Änderungen sind `"–"` → `"high"`; keine Zeile
verliert eine Wichtigkeit, kein anderes Feld (Titel, Datum, Zeit, Kontexte, Dauer, Ort, Dringlichkeit) ändert sich.

| Schlüssel | Titel | Änderung | Begründung |
|---|---|---|---|
| `de-ich-2` | Ich sollte den Steuerberater endlich zurückrufen | importance – → high | Stamm `steuerberater` (officialStem), Amtssprache |
| `de-kontrolle-17` | Die Steuerbescheide der letzten Jahre sortieren | importance – → high | Stamm `steuerbescheid` mit Mehrzahlendung „-e“ (rechts offen) |
| `de-stichwort-6` | Steuerberater | importance – → high | Stamm `steuerberater` |
| `de-zeit-hinten-1` | Steuerberater anrufen | importance – → high | Stamm `steuerberater` |
| `de-zwei-6` | Steuerberater zurückrufen und die Belege sortieren | importance – → high | Stamm `steuerberater` |

Abgleich mit der Messung der Spec: dort 4× `steuerberater` neu + 1× `steuerbescheide` = 5 neue Treffer — deckt sich.
Der Sprachfehler „Steuerbrater“ aus dem Prototyp (generischer Stamm `steuer…`) trifft mit den Positivlisten nicht
mehr; das ist gewollt (Positivliste statt generischem Präfix, Spec „Implementation Details“). Die Zeilen mit
„Mietvertrag“/„Mietvertrags“ hatten über das Ganzwort „Anwalt“ schon `high` und bleiben unverändert.
