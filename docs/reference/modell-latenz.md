# Modell-Latenz auf dem Mac (#534, Schnitt 1)

Wie lange braucht ein Aufruf des On-Device-Modells, kalt und warm? Grundlage für das Limit je Modellaufruf im
`EnrichmentCoordinator` (heute 30 s, geschätzt in #530). Dieser Bericht **legt keine neue Zahl für das Produkt fest**: Das iPhone
fehlt noch (Schnitt 2), und das Limit richtet sich nach dem langsameren Gerät.

## Messaufbau

| | |
|---|---|
| Gerät | Mac mit Apple M4 |
| System | macOS 27.0.1 |
| Bau | Debug, Testprozess des Schemas `LooseEnds`, `FoundationModelsEnricher` unverändert (frische `LanguageModelSession` je Aufruf, kein `prewarm()`) |
| Weg | `./scripts/sim.sh real-model-latency 15` (`RealModelLatencyTests`, ein Prozess je Lauf) |
| Läufe | 15 Prozesse nacheinander am 2026-10-21; je Prozess 1 kalter und 10 warme Aufrufe |
| Eingabe | die sechs erfundenen Notizen aus `RealModel.notes`, Wörterbuch aus sechs Standardkontexten, keine Beispiele |
| Rohdaten | `docs/artifacts/534-modell-latenz/lauf-01.json` … `lauf-15.json`, Auswertung `scripts/latency_summary.py` |

**Kalt heißt prozess-kalt:** der erste Aufruf nach dem Start des Testprozesses. Ob das Betriebssystem das Modell zusätzlich neu
laden muss (nach Neustart, nach iOS-Update, nach langer Ruhe), lässt sich im Test nicht erzwingen und ist hier **nicht** gemessen.

## Ergebnis

| Gruppe | n | Minimum | Median | p95 | Maximum | Fehler |
|---|---|---|---|---|---|---|
| kalt | 15 | 2,77 s | 3,15 s | 4,20 s | 4,20 s | 0 |
| warm | 150 | 2,52 s | 3,14 s | 3,73 s | 4,67 s | 0 |

- Kalt und warm liegen praktisch gleich (Median 3,15 gegen 3,14 s). Der größte kalte Wert (4,20 s) ist kleiner als der größte warme (4,67 s).
  Der Kaltstart des Prozesses kostet auf dem Mac keine messbare Zeit; die Last liegt im Aufruf selbst.
- Das Verhältnis Kalt-Maximum zu Warm-Maximum ist 0,9, weit unter der Schwelle Faktor 5.
- p95 beschreibt nur: bei n = 15 (kalt) ist es der größte Wert. Die Grenze trägt das Maximum.
- Das heutige Limit von 30 s liegt beim 6,4-fachen des größten Messwerts (4,67 s).

## Einordnung

**Wofür das Modell noch gebraucht wird.** Der Titel wird beim Erfassen von `TitleRule` aus dem bereinigten Rohtext gesetzt (#202), das Datum
von der Regel (#95), Kontexte setzt das Modell nie (#215). Übrig bleibt die Verfeinerung des Titels. Ohne Modell geht es nicht, weil dafür
Sprachverstehen nötig ist; die Regel-Spalte entfällt hier, weil es für Latenz keine Regel gibt, die das Modell ersetzt.

**Zwei Grenzen (Alternative B)?** Empfehlung: nein. Kalt und warm unterscheiden sich auf dem Mac nicht (Faktor 0,9 statt über 5), eine
zweite Grenze würde nichts verkürzen. Die Entscheidung fällt in Schnitt 2, nachdem das iPhone gemessen ist; weicht es dort stark ab,
wird sie neu gestellt.

**Vorläufige Rechnung, nicht festgelegt.** Maximum 4,67 s mit Abstand 3 bis 4 ergibt rund 14 bis 19 s. Das ist ein Mac-Wert; das iPhone 16 Pro
kann eine andere Modellgeneration und weniger Leistung haben (die ältere Notiz „Mac = alte Modellgeneration“ gilt auf macOS 27.0.1 nicht mehr
ungeprüft). Abgeleitet wird in Schnitt 2 aus dem größeren der beiden Maxima.

## Grenzen der Messung

- Nur der Mac, nur prozess-kalt, nur sechs kurze Notizen mit kleinem Kontextwörterbuch. Längere Rohtexte oder ein größeres Wörterbuch
  (z. B. viele Projekte) sind nicht abgedeckt.
- Der Mac war ungestört. Last durch andere Apps, Akku-Sparmodus oder Hitze (auf dem iPhone relevant) sind nicht gemessen; Apple gibt
  an, dass das System das Modell bei Last anders einplanen kann.
- Keine veröffentlichte Latenzmessung von Apple gefunden; ein Fallbericht nennt 1 bis 2 s Kaltstart (anekdotisch). Quellen:
  Apple `LanguageModelSession.prewarm(promptPrefix:)`, Apple-Forum-Thread 844222.

## Offen

- **Schnitt 2:** iPhone-Messung über die Labor-App (Dauer je Aufruf liegt in `MeasurementResult.seconds` vor), danach die Konstante im
  `EnrichmentCoordinator` mit Verweis auf diesen Bericht. Stufe 3; erst nach Hennings „jetzt ist ein Test möglich“.
- `prewarm()` beim Start bleibt ein eigenes Ticket; die Messung zeigt auf dem Mac keinen Kaltstart-Aufschlag, den es verkürzen könnte.
