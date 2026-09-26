# Regel-Auslass-Test: Wortüberlappung als Nachbarsuche (Spike #69, #131)

Auslass-Test ohne Modell: für jede Aufgabe entscheiden die k ähnlichsten *anderen* Aufgaben
per Mehrheit über ein Merkmal. Ähnlichkeit ist der Jaccard-Koeffizient über die Wortmengen
der Titel, gefiltert auf Wörter ab vier Zeichen.

| Merkmal | Pool | Methode |
|---|---|---|
| Kontexte | 104 | exakte Mengengleichheit |
| Dauer | 276 | exakte Gleichheit |
| Energie | 211 | exakte Gleichheit |

Korpus: `docs/reference/focusblox-corpus.json` (287 Aufgaben) ·
Messtag: 2026-09-26 · Methode: Regel-Auslass-Test, kein Modell, kein Gerät.

Im Pool eines Merkmals steht nur, wer für dieses Merkmal eine Wahrheit trägt. Bei Kontexten
heißt das: die 183 Aufgaben mit leerer Kontextliste sind
keine Klasse „ohne Kontexte", sondern fehlende Wahrheit — sie sind weder Prüffall noch
Nachbar noch Vorhersagewert.

## Ergebnis je Merkmal und k

| Merkmal | k | Trefferquote | ... unter beantworteten | ohne Nachbarn | Nulllinie | Abstand | b | c | p-Wert | Urteil |
|---|---|---|---|---|---|---|---|---|---|---|
| Kontexte | 1 | 72.1 % | 88.2 % | 19 | 56.7 % | 15.4 % | 25 | 9 | 0.0090 | erfüllt |
| Kontexte | 3 | 72.1 % | 88.2 % | 19 | 56.7 % | 15.4 % | 25 | 9 | 0.0090 | erfüllt |
| Kontexte | 5 | 72.1 % | 88.2 % | 19 | 56.7 % | 15.4 % | 25 | 9 | 0.0090 | erfüllt |
| Dauer | 1 | 73.9 % | 82.3 % | 28 | 51.1 % | 22.8 % | 101 | 38 | 0.0000 | erfüllt |
| Dauer | 3 | 72.1 % | 80.2 % | 28 | 51.1 % | 21.0 % | 98 | 40 | 0.0000 | erfüllt |
| Dauer | 5 | 72.1 % | 80.2 % | 28 | 51.1 % | 21.0 % | 97 | 39 | 0.0000 | erfüllt |
| Energie | 1 | 60.2 % | 69.4 % | 28 | 77.3 % | -17.1 % | 2 | 38 | 0.0000 | nicht erfüllt |
| Energie | 3 | 59.7 % | 68.9 % | 28 | 77.3 % | -17.5 % | 0 | 37 | 0.0000 | nicht erfüllt |
| Energie | 5 | 59.2 % | 68.3 % | 28 | 77.3 % | -18.0 % | 16 | 54 | 0.0000 | nicht erfüllt |

## Gegenprobe ohne Textdubletten (k = 1)

Dieselbe Rechnung, dieselben Spalten, ein Vertreter je textgleicher Gruppe: aus 104 /
276 / 211 Aufgaben werden 50 / 115 / 119.

| Merkmal | k | Trefferquote | ... unter beantworteten | ohne Nachbarn | Nulllinie | Abstand | b | c | p-Wert | Urteil |
|---|---|---|---|---|---|---|---|---|---|---|
| Kontexte (n = 50) | 1 | 30.0 % | 55.6 % | 23 | 32.0 % | -2.0 % | 6 | 7 | 1.0000 | nicht erfüllt |
| Dauer (n = 115) | 1 | 32.2 % | 44.6 % | 32 | 56.5 % | -24.3 % | 12 | 40 | 0.0001 | nicht erfüllt |
| Energie (n = 119) | 1 | 49.6 % | 67.8 % | 32 | 83.2 % | -33.6 % | 2 | 42 | 0.0000 | nicht erfüllt |

## Nebenspalten für Kontexte (nur zur Nachprüfbarkeit der Metrikwahl)

Verbindlich ist allein die exakte Mengengleichheit oben. Die folgenden zwei Lesarten stehen
hier, damit die Metrikwahl überprüfbar bleibt — auf sie stützt sich keine Entscheidung.
Gerechnet auf demselben Kontext-Pool wie die Haupttabelle (104 Aufgaben mit
Kontext-Wahrheit), nicht auf allen 287.

| k | enthält erwarteten Kontext | Jaccard-Mittel |
|---|---|---|
| 1 | 73.1 % | 72.6 % |
| 3 | 73.1 % | 72.6 % |
| 5 | 73.1 % | 72.6 % |

## Urteil nach der vorab festgelegten Schwelle

Erfüllt heißt: bei mindestens einem k liegt die Trefferquote mindestens 10 Prozentpunkte
über der Nulllinie **und** der zweiseitige McNemar-Exakttest ergibt p < 0,05.

- Kontexte: erfüllt
- Dauer: erfüllt
- Energie: nicht erfüllt

Diese drei Wörter gelten für den vollen Pool, so wie die Schwelle vorab festgelegt wurde. Die
Gegenprobe ohne Textdubletten oben fällt anders aus — wer nur das Urteil liest, liest halb.

## Grenzen dieser Zahlen

- Der Korpus trägt gepflegte Titel als Rohtext (`scripts/export-focusblox-corpus.swift`
  setzt `rawText: title`). Jede Zahl hier gilt für Titel, nicht für diktierten Rohtext, wie
  ihn das Produkt verarbeitet.
- Geprüft ist ein Mechanismus: Wortüberlappung. Ein Nullergebnis widerlegt diesen
  Mechanismus, nicht Annahme B1 insgesamt und nicht den Modellweg.
- Der Ähnlichkeitsfilter verwirft Wörter unter vier Zeichen und damit kurze Inhaltswörter
  („Tee", „Bad", „App").
- Bei Kontexten ist die Stichprobe klein genug, dass ein realer Vorsprung von 10 bis 12
  Punkten an der Signifikanz scheitern kann; bei Dauer und Energie kann umgekehrt ein
  signifikanter Vorsprung unter 10 Punkten als „nicht erfüllt" gelten.
- **Der Korpus enthält große Gruppen exakt textgleicher Aufgaben.** Einen Nachbarn mit Jaccard
  1,0, also identischer Wortmenge, haben 58.7 % der Kontext-,
  61.2 % der Dauer- und 47.9 % der Energie-Sätze; für sie ist die
  Nachbarsuche Wiedererkennung desselben Titels, keine Ähnlichkeitsaussage. Die Haupttabelle
  zeigt deshalb den Nutzen bei **wiederkehrenden** Erfassungen, die Gegenprobe den bei **neu
  formulierten** Aufgaben. Beide Lesarten führen zu unterschiedlichen Entscheidungen — welche
  gilt, ist eine Produktfrage, deshalb stehen beide Tabellen hier, nicht nur die günstigere.
