---
spec_file: docs/specs/fix-377-mac-abgleich.md
spec_sha256: 850e03edda7750edadfc618bfa486ad968c2c1f2b783f54d01340e8a16f0a65a
---

# PO-Briefing: fix-377-mac-abgleich

- **Spec:** docs/specs/fix-377-mac-abgleich.md
- **Issue:** #377
- **Erstellt:** 2026-10-13

## Was gebaut wird

Die Einstellungen zeigen, ob die App mit iCloud abgleicht; auf dem Mac wird dafür ein fehlender Baustein ergänzt.

## Definition of Done

Im Simulator zeigt die Zeile „iCloud-Abgleich“ in Hell und Dunkel, Tests grün; die Mac-Antwort folgt später, #377 bleibt offen.

## Wie geprüft wird

Tests belegen die Auswertungsregel und die sichtbare Zeile im Simulator; ob iCloud-Meldungen ankommen und was der Mac zeigt, belegen sie nicht.

## Kritische Anmerkungen

- Neu gegenüber der Freigabe: Ob iCloud-Meldungen ankommen, ist im Simulator unbeantwortbar und wird nachgelagert mit dem Mac-Test geprüft; beides verbindlich.
- Mac zeigt womöglich erstmals zusammengeführte Aufgaben; nichts wird gelöscht. Nur Anzeige, keine Reparatur.
- Sechs statt fünf Dateien, wegen einer Zusicherung im Bedienungstest.

## Freigabe-Frage

Gibst du diese Fassung frei, mit Mac-Test nachgelagert und #377 weiter offen?
