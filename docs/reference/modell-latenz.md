# Modell-Latenz auf Mac und iPhone (#534, Schnitt 1 bis 3)

Wie lange braucht ein Aufruf des On-Device-Modells, kalt und warm? Grundlage für das Limit je Modellaufruf im
`EnrichmentCoordinator`: **25 s** (`EnrichmentCoordinator.defaultModelTimeout`, gesetzt in Schnitt 3, #534), abgeleitet aus dieser
Messung; es ersetzt die in #530 geschätzten 30 s. Das Limit richtet sich nach dem langsameren Gerät (iPhone).

## Messaufbau Mac (Schnitt 1)

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
- Das Limit von 25 s liegt beim 5,4-fachen des größten Messwerts am Mac (4,67 s); das frühere geschätzte von 30 s lag beim 6,4-fachen.

## iPhone (Schnitt 2)

| | |
|---|---|
| Gerät | iPhone 16 Pro (`iPhone17,1`), iOS 27.0.1 (aus `Conditions` der Labor-App) |
| Bau | Labor-App `LE Labor` (Debug, signiert), Produkt-`FoundationModelsEnricher` unverändert |
| Weg | `./scripts/sim.sh lab-latency 10` am 2026-10-23: zehn Starts nacheinander, je Start 12 Aufrufe (zwei Durchgänge über dieselben sechs Notizen), die App beendet sich selbst |
| Eingabe | dieselben sechs Notizen wie am Mac (`Measurement/latency-corpus.json`, Test gegen `RealModel.notes`), dasselbe Wörterbuch aus sechs Standardkontexten |
| Rohdaten | `docs/artifacts/534-modell-latenz/iphone/latency-01.json` … `latency-10.json`, Auswertung `scripts/latency_summary.py` |

Die Labor-App wurde vor dem Lauf entfernt und neu installiert, damit keine alte Ergebnisdatei den Lauf verkürzt. Ein Entwickler-Test
(`MeasurementRunTests.latencyLaunchMakesEveryRun`) belegt, dass jeder Start alle 12 Aufrufe macht.

| Gruppe | n | Minimum | Median | p95 | Maximum | Fehler |
|---|---|---|---|---|---|---|
| kalt | 10 | 4,17 s | 4,68 s | 7,92 s | 7,92 s | 0 |
| warm | 110 | 4,15 s | 4,83 s | 5,96 s | 6,72 s | 0 |

**Hitze.** 112 der 120 Aufrufe liefen bei Hitzestufe „serious“, 8 bei „fair“, keiner bei „normal“. Das iPhone war also durchgehend warm,
vermutlich vom Bau und von den Läufen davor; ein kühles Gerät ist nicht gemessen. Maxima je Stufe: kalt fair 7,92 s (ein Wert),
kalt serious 5,11 s; warm fair 5,61 s (7 Werte), warm serious 6,72 s (103 Werte). Die Stufe „fair“ hat zu wenige Werte für einen
Schluss; das größte Maximum stammt von einem einzelnen kalten Aufruf.

**Strom.** Alle 120 Aufrufe liefen auf Akku, ohne Stromsparmodus. **Vordergrund.** Der erste Aufruf jedes Starts läuft im Zustand
„inaktiv“ (App noch im Start), die übrigen im Vordergrund; die kalten Werte enthalten also den Start der App.

- Kalt und warm liegen auch auf dem iPhone nah beieinander (Median 4,68 gegen 4,83 s). Das Verhältnis Kalt-Maximum zu Warm-Maximum ist
  1,2, weit unter der Schwelle Faktor 5.
- p95 beschreibt nur; bei n = 10 (kalt) ist es der größte Wert. Die Grenze trägt das Maximum.
- Keine Fehler und keine Zeitüberschreitung in 120 Aufrufen.

**Mac gegen iPhone.**

| | Mac M4 | iPhone 16 Pro | Faktor |
|---|---|---|---|
| Median warm | 3,14 s | 4,83 s | 1,5 |
| Maximum warm | 4,67 s | 6,72 s | 1,4 |
| Maximum kalt | 4,20 s | 7,92 s | 1,9 |

Das iPhone ist langsamer als der Mac, aber nicht um Größenordnungen. Das Limit richtet sich nach dem iPhone.

## Einordnung

**Wofür das Modell noch gebraucht wird.** Der Titel wird beim Erfassen von `TitleRule` aus dem bereinigten Rohtext gesetzt (#202), das Datum
von der Regel (#95), Kontexte setzt das Modell nie (#215). Übrig bleibt die Verfeinerung des Titels. Ohne Modell geht es nicht, weil dafür
Sprachverstehen nötig ist; die Regel-Spalte entfällt hier, weil es für Latenz keine Regel gibt, die das Modell ersetzt.

**Zwei Grenzen (Alternative B)?** Empfehlung: nein. Kalt und warm unterscheiden sich weder am Mac (Faktor 0,9) noch auf dem iPhone
(Faktor 1,2) um mehr als die Schwelle 5; eine zweite Grenze würde nichts verkürzen.

**Gesetzt in Schnitt 3: 25 s** (Henning, 2026-10-23: „25 s umsetzen“). Regel: das Dreifache des größten gemessenen Werts beider Geräte,
aufgerundet auf volle 5 s, mindestens 15 s; über 60 s geht die Frage an Henning zurück. Größter Wert ist 7,92 s (iPhone, kalt).
3 × 7,92 s = 23,8 s, aufgerundet **25 s**, im erlaubten Bereich; das ist das 3,2-fache des größten Werts. Die frühere Schätzung von 30 s
(Faktor 3,8) war kein Fehler, hatte aber keinen Messbezug. Die Konstante heißt `EnrichmentCoordinator.defaultModelTimeout`; die Prüfung gegen
das echte Modell (`RealModelTests`) liest dieselbe Konstante, und `ModelSeamTests.defaultLimitIsMeasured` hält Wert und Regelbereich fest.

**Alternativen (abgewogen).** (a) 30 s lassen: kein Eingriff in eine Gerätepfad-Datei, Abstand 3,8; die Messung widerlegt sie nicht, aber die
Zahl bliebe geschätzt. (b) 25 s nach der Regel, gewählt.
(c) Erst auf kühlem Gerät und mit längeren Notizen nachmessen, bevor die Zahl sich ändert: Die Messung lief fast ganz bei „serious“ und mit
kurzen Notizen, also eher im ungünstigen Bereich für die Hitze, aber nicht für die Länge.

## Grenzen der Messung

- Nur prozess-kalt, nur sechs kurze Notizen mit kleinem Kontextwörterbuch. Längere Rohtexte oder ein größeres Wörterbuch
  (z. B. viele Projekte) sind nicht abgedeckt.
- Der Mac war ungestört. Das iPhone war warm („serious“) und lief auf Akku im Vordergrund; kühles Gerät, Stromsparmodus, Hintergrund
  und Last durch andere Apps sind nicht gemessen. Apple gibt an, dass das System das Modell bei Last anders einplanen kann.
- Keine veröffentlichte Latenzmessung von Apple gefunden; ein Fallbericht nennt 1 bis 2 s Kaltstart (anekdotisch). Quellen:
  Apple `LanguageModelSession.prewarm(promptPrefix:)`, Apple-Forum-Thread 844222.

## Offen

- `prewarm()` beim Start bleibt ein eigenes Ticket; die Messung zeigt auf dem Mac keinen Kaltstart-Aufschlag, den es verkürzen könnte.
