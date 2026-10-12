# Gerätelauf #274 — Beleg (iPhone 16 Pro, iOS 27.0, 2026-10-08)

Prüfbau `com.henning.looseends.probe` („LE Prüfbau“), Stand: Diagnosezeile + Befunde F001–F004 behoben, mit Debug-Startargument
`--debug-open-capture` in einer Wegwerf-Kopie (nicht im Repo). Gestartet auf dem direkten Weg (`devicectl device process launch`),
weil der Messkanal `xctrace --launch` das Gerät in vier Versuchen nicht erreichte („Instruments will start recording when … is
unlocked“, „Device is offline“, „Waiting for device to boot“, Trace leer). Es gibt deshalb **kein Mac-Protokoll**; der Beleg ist
Hennings Beobachtung am Bildschirm.

## Hennings Beobachtung (wörtlich, Punkt 6)

„die graue Zeile war da und sah inhaltlich sinnvoll aus und verschwand, sobald ich gesprochen habe.“

| AC | Befund |
|---|---|
| AC-1 Zeile erscheint nach Stille | belegt (Zeile war da) |
| AC-4 Zeile verschwindet bei Text | belegt (verschwand beim Sprechen) |
| AC-6 Inhalt sinnvoll | belegt (Henning: „inhaltlich sinnvoll“) |
| AC-5 Neustart beginnt bei 0 | **am Gerät nicht beobachtet** (Henning nannte den Neustart nicht); belegt nur durch Lesen des Codes (`stop()`/Start setzen Zähler zurück) |
| Messkanal / Mac-Protokoll | nicht vorhanden (s. o.) |

## Weitere Beobachtungen (nicht Teil von #274, in eigenem Ticket erfasst)

1. Text erscheint deutlich verzögert.
2. Ausschläge der gepunkteten Wellenlinie sehr gering; kaum erkennbar, dass aufgezeichnet wird.
3. Ergebnisse kommen nicht flüssig: erste zwei Wörter eines kurzen Satzes, die nächsten zwei erst nach ca. 8 s.
4. Erkannter Text ist gut.
5. Gefülltes vs. nicht gefülltes Mikrofon-Symbol zeigt nicht eindeutig, ob zugehört wird.
