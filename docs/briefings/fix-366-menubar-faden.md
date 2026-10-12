---
spec_file: docs/specs/fix-366-menubar-faden.md
spec_sha256: cee1509bc6e2ecfbf682bef7e6b61907890daf016c84a0d115dcb12353d3c346
---

# PO-Briefing: fix-366-menubar-faden

- **Spec:** docs/specs/fix-366-menubar-faden.md
- **Issue:** #366
- **Erstellt:** 2026-10-12

## Was gebaut wird

Die Mac-Menüleiste zeigt statt des Standardsymbols den Knoten mit dem losen Faden aus dem Logo.

## Definition of Done

Screenshots der Menüleiste in Hell und Dunkel zeigen den Faden erkennbar, und das Panel öffnet und erfasst wie bisher.

## Wie geprüft wird

Tests belegen Zeichnung, Größe und Kreuzungslücke im Simulator; Hell/Dunkel-Färbung und Panel prüft kein automatischer Test.

## Kritische Anmerkungen

- Hell/Dunkel-Färbung und Panel-Funktion sind nur per Mac-Prüfbau belegt, der erst nach Ihrem „jetzt ist ein Test möglich" läuft.
- „Erkennbar" ist Geschmackssache; läuft die Lücke zu, wechselt die Umsetzung ohne Rückfrage auf einen kräftigeren Faden.

## Freigabe-Frage

Soll der Knoten in Logo-Strichstärke gebaut werden, mit automatischem Wechsel auf kräftigeren Faden, falls er klein unleserlich wird?
