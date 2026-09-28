---
spec_file: docs/specs/enrichment/fix-144-recognition-pool-empty.md
spec_sha256: e186109cde444d8ab4c7e9384bfbcc18d7f05d018582e802d624de317d211367
---

# PO-Briefing: fix-144-recognition-pool-empty

- **Spec:** docs/specs/enrichment/fix-144-recognition-pool-empty.md
- **Issue:** #144
- **Erstellt:** 2026-09-28

## Was gebaut wird

Wiedererkennung übernimmt Dauer und Kontext einer wortgleichen Wiederholung künftig auch ohne funktionierendes KI-Modell.

## Definition of Done

Fertig, wenn eine wortgleiche Zweiterfassung automatisiert, im Simulator und auf Hennings iPhone dieselbe Dauer und denselben Kontext zeigt.

## Wie geprüft wird

Automatisierte Tests, ein Simulator-Durchlauf und eine Korpus-Messung belegen es; ob der Beleg zum aktuellen Stand passt, prüft kein Werkzeug.

## Kritische Anmerkungen

- Nach Hennings Freigabe wurde eine zugesagte Prüfbedingung korrigiert: von vier auf drei Testsätze, eine war unerfüllbar.
- Die Spec ändert zusätzlich eine ältere, freigegebene Spezifikation — mehr als das Ticket verlangt.
- Ob der Messbeleg zum aktuellen Stand gehört, prüft kein Werkzeug — offen bis zu einem späteren Ticket.

## Freigabe-Frage

Reicht Ihnen der Nachweis mit drei Prüfsätzen statt der ursprünglich vier zugesagten, oder verlangen Sie die vierte Bedingung?
