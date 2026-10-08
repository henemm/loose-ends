---
spec_file: docs/specs/fix-274-sichtbare-spracheingabe-diagnose.md
spec_sha256: 92140878749e26d3f7333949ca4a8f3f10cb80e60a7a061a4f1206c37da63d24
---

# PO-Briefing: fix-274-spracheingabe-kein-text

- **Spec:** docs/specs/fix-274-sichtbare-spracheingabe-diagnose.md
- **Issue:** #274
- **Erstellt:** 2026-10-08

## Was gebaut wird

Bei Ton ohne erkannten Text zeigt die Spracheingabe nach 6 Sekunden eine graue Diagnosezeile, repariert aber nichts.

## Definition of Done

Auf iPhone und iPad zeigt die TestFlight-App bei Ton ohne Text die Diagnosezeile; Henning sendet sie, Ursache bleibt offen.

## Wie geprüft wird

Tests belegen Schwellenregel und Zeilentext im Simulator; Zähler, Verschwinden und Neustart prüft nur ein Lauf auf dem iPhone, nicht das iPad.

## Kritische Anmerkungen

- Ziel „Text wieder da" wird verfehlt; #274 bleibt offen, der eigentliche Fix folgt erst nach Hennings Rückmeldung.
- Leere Ergebnisse unterdrücken die Zeile: „Kein Text" ohne Zeile bleibt möglich.
- Sechs statt fünf Dateien, begründet; Wirkung auf dem iPad nur über TestFlight prüfbar.

## Freigabe-Frage

Soll diese reine Diagnose-Version ausgeliefert werden, obwohl die Spracheingabe danach noch keinen Text liefert?
