---
spec_file: docs/specs/feat-342-schnitt-1a-hinweis-ohne-modell.md
spec_sha256: 02ff450b3527a9d78a441a654bdc37f5baf60275b2e27b606fcd9e5d5afc9cd0
spec_frozen_sha256: e0eb7870a188ca600c337f1e74f118e89c748451afbdee3b9553396775eac9f3
---

# PO-Briefing: 342-sprache-und-start-ohne-modell

- **Spec:** docs/specs/feat-342-schnitt-1a-hinweis-ohne-modell.md
- **Issue:** #342
- **Erstellt:** 2026-10-26

## Was gebaut wird

Auf Geräten ohne Apple Intelligence sagt der Willkommens-Hinweis ehrlich, was weiter automatisch erkannt wird und was nicht.

## Definition of Done

Im Simulator erscheint der Hinweis in allen drei Fällen, der Fall ohne Modell mit neuem Wortlaut auf Deutsch und Englisch.

## Wie geprüft wird

UI-Tests lesen den Hinweistext vom Bildschirm und vergleichen ihn wörtlich; ein echtes Gerät ohne Apple Intelligence wird nicht getestet.

## Kritische Anmerkungen

- Deutsch/Englisch bleibt fast ganz offen: Uhr-Komplikation, Berechtigungstexte, Label „Counts“, Vollständigkeitsprüfung folgen später.
- Hinweis wird per Testschalter erzwungen; ob er auf einem echten Gerät ohne Modell erscheint, bleibt unbelegt.
- Neuer Wortlaut braucht deine Freigabe; Satz „Aufgaben behalten deine Worte“ entfällt.

## Freigabe-Frage

Gibst du den neuen Hinweistext für Geräte ohne Apple Intelligence frei, obwohl Uhr und Berechtigungstexte später folgen?
