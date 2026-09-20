---
spec_file: docs/specs/measurement/issue-82-satzformen.md
spec_sha256: c369a37e1cd08cfd48fc8587b1c2dc74d86eb1773fbcf998699e7774f38993df
---

# PO-Briefing: issue-82-satzformen

- **Spec:** docs/specs/measurement/issue-82-satzformen.md
- **Issue:** #82
- **Erstellt:** 2026-09-20

## Was gebaut wird

Die Testsätze für die Messung bekommen vielfältigere Formen (Stichwörter, Ich-Sätze, Fragen, Diktate), der Bericht zeigt Ergebnisse je Form.

## Definition of Done

Fertig ist es, wenn der Bericht die Trefferquote je Satzform zeigt und alle bisherigen Auswertungen weiter funktionieren.

## Wie geprüft wird

Automatisierte Tests prüfen, ob jede Satzform korrekt erkannt und ausgewertet wird; eine echte Messung auf dem Gerät folgt separat.

## Kritische Anmerkungen

- Hennings 108 tatsächliche Rohsätze aus FocusBlox fehlen in diesem Schnitt; nur erfundene Sätze in seinem Stil werden gemessen.
- Die neue Satzverteilung bildet Hennings reale Nutzung (nur 12 % mit Zeitangabe) nicht nach; Formen sind nur gleichmäßig aufgeteilt.

## Freigabe-Frage

Reicht es, jetzt nur erfundene Sätze in vielfältigen Formen zu messen, während Ihre echten 108 Sätze in einem späteren Schritt folgen?
