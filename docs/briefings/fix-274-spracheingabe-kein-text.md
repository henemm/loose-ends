---
spec_file: docs/specs/fix-274-sichtbare-spracheingabe-diagnose.md
spec_sha256: dba554cb7264ec9de100d20acc5ddb9a1e27e41091a7018d05d6f533345f8e3c
---

# PO-Briefing: fix-274-spracheingabe-kein-text

- **Spec:** docs/specs/fix-274-sichtbare-spracheingabe-diagnose.md
- **Issue:** #274
- **Erstellt:** 2026-10-08

## Was gebaut wird

Bei Ton ohne erkannten Text zeigt die Spracherfassung nach 6 Sekunden eine graue Diagnosezeile, damit die Ursache sichtbar wird.

## Definition of Done

Auf Hennings iPhone erscheint die Zeile nach 6 Sekunden ohne Text und verschwindet beim ersten Ergebnis; Text kommt dadurch nicht zurück.

## Wie geprüft wird

Unit- und Oberflächentests belegen Schwelle, Text und festen Anzeigezustand; Neustart, Aussehen, Modellgrund-Fälle und unveränderte Erkennung haben keinen automatischen Test.

## Kritische Anmerkungen

- Ziel „Text wieder da“ wird nicht erreicht; Ticket #274 bleibt offen, bis Hennings Zeile ausgewertet und ein Fix gebaut ist.
- Am Gerät belegt sind nur Erscheinen, Verschwinden, Inhalt (Hennings Beobachtung); Neustart nur durch Code-Lesen, von Henning akzeptiert.
- Sechs statt fünf Dateien; Grenze überschritten, begründet.

## Freigabe-Frage

Gibst du diese reine Diagnose frei, obwohl #274 offen bleibt?
