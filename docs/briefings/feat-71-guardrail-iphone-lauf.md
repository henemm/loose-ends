---
spec_file: docs/specs/spike-71-schnitt-2b-iphone-lauf.md
spec_sha256: d2c14650b19c9358cc495957af842551cd31019ffe9bf98e6c531679179424f9
spec_frozen_sha256: 5bd1d4fbaf046a36c986ecf1b40e207af1c1773ab77d00e97f15189dcc923da3
---

# PO-Briefing: feat-71-guardrail-iphone-lauf

- **Spec:** docs/specs/spike-71-schnitt-2b-iphone-lauf.md
- **Issue:** #71
- **Erstellt:** 2026-10-28

## Was gebaut wird

Die Auswertung für die spätere iPhone-Ablehnungsmessung entsteht; noch keine iPhone-Zahl, nichts läuft auf dem Gerät.

## Definition of Done

Auswertung im Simulator mit gestellten Daten durchgespielt: Rohdaten ohne persönliche Sätze, Zusammenfassung mit Treffer; Gerätelauf und B3-Entscheidung folgen erst nach dem zweiten Teil.

## Wie geprüft wird

Tests mit erfundenen Daten belegen Zählung, Datenschutz und Vollständigkeitsprüfung; sie beweisen nicht, dass das iPhone-Modell Alltagstext durchlässt.

## Kritische Anmerkungen

- Gerätelauf fehlt noch: Ohne Teil 2b-2 gibt es keine Zahl; Ticket #71 und Entscheidung zur 1-%-Schwelle bleiben offen.
- Simulator-Durchlauf steht nur in der Definition of Done, nicht als nummeriertes Kriterium mit Test.
- Zeitüberschreitungen und Ähnliches werden aus der Rate herausgerechnet; viele davon würden die Ablehnungsrate beschönigen.

## Freigabe-Frage

Soll die Auswertung jetzt gebaut werden, obwohl die iPhone-Zahl erst nach dem zweiten Teil kommt?
