---
spec_file: docs/specs/measurement/spike-108-selbstkonsistenz-signal.md
spec_sha256: 9f19752a89ce516676c70b829d81f15fe798b6eade68df01cf8df23ca9f6df3e
---

# PO-Briefing: spike-108-selbstkonsistenz-signal

- **Spec:** docs/specs/measurement/spike-108-selbstkonsistenz-signal.md
- **Issue:** #108
- **Erstellt:** 2026-09-22

## Was gebaut wird

Ein Mess-Werkzeug zählt, wie einstimmig das Modell fünf Aufgaben-Eigenschaften über mehrere Wiederholungen beantwortet — ohne eigenes Messergebnis.

## Definition of Done

Fertig ist es, wenn die Prüfwerkzeuge fehlerfrei laufen und ein leeres Berichts-Gerüst besteht — der tatsächliche Gerätelauf folgt später.

## Wie geprüft wird

Automatisierte Prüfungen zeigen, dass Zählung und Mehrheitsermittlung rechnerisch stimmen; sie belegen keine echte Modell-Einstimmigkeit, weil kein Gerätelauf stattfindet.

## Kritische Anmerkungen

- Ursprünglich sieben Aufgaben-Eigenschaften angefragt, Spec deckt nur fünf ab — zwei fehlen mangels Vergleichsdaten.
- Eine zusätzliche Datei liegt jetzt im Bereich, der auch in die echte App einfließt, nicht nur im Messbereich.
- Ein Prüfpunkt läuft nicht automatisiert mit, sondern nur über einen manuellen Probe-Lauf des Export-Skripts.

## Freigabe-Frage

Ist es für Sie in Ordnung, das Mess-Werkzeug ohne die beiden fehlenden Eigenschaften und mit der Datei im App-Bereich freizugeben?
