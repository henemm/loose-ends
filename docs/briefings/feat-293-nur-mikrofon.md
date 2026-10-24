---
spec_file: docs/specs/feat-293-nur-mikrofon.md
spec_sha256: 947c7ca5c452d96a9659ffc398812b2279b90a583092b55fba386ee56f77913d
spec_frozen_sha256: 3edb69069c5088aa1ca54070b84949d32becdaba6a9f055de7cf5534a9b26d8a
---

# PO-Briefing: feat-293-nur-mikrofon

- **Spec:** docs/specs/feat-293-nur-mikrofon.md
- **Issue:** #293
- **Erstellt:** 2026-10-24

## Was gebaut wird

Die Spracherfassung fragt und prüft nur noch das Mikrofon, die Sperre wegen fehlender Spracherkennung entfällt.

## Definition of Done

Auf dem Mac erscheint beim frischen Start genau ein Dialog, danach hört die Erfassung zu und liefert Text.

## Wie geprüft wird

Automatische Tests prüfen Mikrofonregel, Meldungen und Diagnosezeile; den echten Ein-Dialog-Ablauf zeigt nur dein späterer Gerätetest.

## Kritische Anmerkungen

- Kein automatischer Test belegt, dass bei abgelehnter Spracherkennung keine Sperre mehr erscheint; das zeigt erst der Gerätelauf.
- Der Beweisversuch nutzte Ton aus Datei, nicht das echte Mikrofon.
- Acht Dateien statt höchstens fünf; Spec begründet es als ein Ziel.

## Freigabe-Frage

Gibst du die Änderung frei, obwohl der Ein-Dialog-Ablauf erst nach dem Merge auf Mac und iPhone bestätigt wird?
