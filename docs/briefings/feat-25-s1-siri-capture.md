---
spec_file: docs/specs/intents/feat-25-s1-siri-capture.md
spec_sha256: 50ec634110b9f887fc59ca08a87c446e5f49ca55c2fe76e4c64d511765bf4129
---

# PO-Briefing: feat-25-s1-siri-capture

- **Spec:** docs/specs/intents/feat-25-s1-siri-capture.md
- **Issue:** #25
- **Erstellt:** 2026-10-15

## Was gebaut wird

Ein Baustein, der Siri-Erinnerungen prüft und als Aufgabe speichert; für Nutzer noch unsichtbar.

## Definition of Done

Alle zwölf Kriterien sind durch grüne Tests belegt, und die App startet unverändert im Simulator.

## Wie geprüft wird

Tests prüfen Zuordnung, Fehlerfälle ohne Rückstände und Schutz vor Überschreiben; echtes Siri-Sprechen wird nicht geprüft.

## Kritische Anmerkungen

- Ticket nicht lesbar; nur gegen Kontext-Dokument geprüft. F1, F2, F3, F5 sind korrekt umgesetzt.
- Bis Schnitt 2 und #240 spürt niemand etwas; Siri-Verhalten bleibt unbewiesen.
- Zwei Kriterien (Signatur unverändert, Prüfschritt schreibt nichts) haben keinen eigenen Test.

## Freigabe-Frage

Soll dieser reine Logik-Schnitt ohne sichtbare Wirkung gebaut werden, mit Siri-Anschluss erst im zweiten Schnitt?
