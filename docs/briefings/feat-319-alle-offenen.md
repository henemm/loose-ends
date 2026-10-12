---
spec_file: docs/specs/feat-319-alle-offenen.md
spec_sha256: e53928da5e6ed2e46b1a3c2918b2e4a7196926a7ee7f77f2229e19ac43254d97
---

# PO-Briefing: feat-319-alle-offenen

- **Spec:** docs/specs/feat-319-alle-offenen.md
- **Issue:** #319
- **Erstellt:** 2026-10-11

## Was gebaut wird

Eine Ansicht „Alle offenen“ über „Erledigt“ zeigt jede nicht erledigte Aufgabe, dringende zuerst.

## Definition of Done

Die Zeile mit Zähler steht über „Erledigt“ und öffnet die Liste mit Geparktem und Wartendem, ohne Erledigtes.

## Wie geprüft wird

Automatische Tests im Simulator belegen Liste, Reihenfolge, Zeile, Leerzustand und Wischgesten; Mac und echte Geräte bleiben ungetestet.

## Kritische Anmerkungen

- Zusatz aus Ihrer Entscheidung: Geparkte bekommen Mond-Symbol und Wisch „Aktivieren“ statt „Als nächstes“; das Ticket verlangt es nicht.
- Sechs Code-Dateien statt vier bis fünf; die Spec begründet die Ausnahme.
- Unverändertes Langdruckmenü und gleiche Oberfläche auf Mac und iPad sind nur per Diff belegt, ohne Test.

## Freigabe-Frage

Geben Sie die Ansicht samt Mond-Symbol und „Aktivieren“-Wisch für Geparktes frei?
