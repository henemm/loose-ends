---
spec_file: docs/specs/feat-344-symbole.md
spec_sha256: 542e33a0acd8bc7175a98f5476783b21bd6df697cfc10961e35bd296e9595c8a
spec_frozen_sha256: f36af7f64635bb5b4dca32bf64cc5ab352add4ec91a57d8c0b3171e026619249
---

# PO-Briefing: feat-344-symbole

- **Spec:** docs/specs/feat-344-symbole.md
- **Issue:** #344 (Text nur über das Kontext-Dokument docs/context/feat-344-symbole.md geprüft)
- **Erstellt:** 2026-10-24

## Was gebaut wird

Wichtig und dringend zeigt die App als Ausrufezeichen und Flamme; im Detail steht hinter fünf Feldern ein Zeichen.

## Definition of Done

Hoch/hoch-Aufgabe zeigt in der Liste Ausrufezeichen und Flamme, das Detail fünf Feldzeichen.

## Wie geprüft wird

Tests prüfen Zuordnung und Vorhandensein der Zeichen, nicht ob sie verständlich oder gut lesbar sind.

## Kritische Anmerkungen

- Zeile bleibt ohne Wort: Flamme und Ausrufezeichen erklären sich nicht selbst, Hennings Kernkritik „unklar“ ist dort nur umgetauscht, nicht gelöst.
- Verlangt war das Zeichen hinter dem Wort; gebaut wird es hinter dem Wert.
- Lesbarkeit kleiner Zeichen ist nur per Bildansicht belegt, nicht per Test.

## Freigabe-Frage

Genügt dir, dass die Liste Zeichen ohne Wort zeigt und die Erklärung nur im Detail steht?
