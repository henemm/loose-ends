---
spec_file: docs/specs/measurement/feat-88-b1-ablage.md
spec_sha256: e6c11dd475be8ea0439a521802bc3ea8a6de741395039a38c0c8b241d024d182
spec_frozen_sha256: 8565de4f0a3f3fae88e56e5e886ae9ddd7661f267b10e270f1ca2e3e0212aa06
---

# PO-Briefing: 88-b1-ablage

- **Spec:** docs/specs/measurement/feat-88-b1-ablage.md
- **Issue:** #88
- **Erstellt:** 2026-10-28

## Was gebaut wird

Das Messlabor findet Hennings Rohsatz-Datei und meldet sichtbar, wenn ein Korpus fehlt, kaputt oder leer ist.

## Definition of Done

Im Simulator zeigt die Labor-App ohne Datei eine Fehlerzeile statt "0 Sätze", mit Testdatei die Satzzahl.

## Wie geprüft wird

Unit-Tests belegen Laden, Fehlergründe und Suchort; Laboranzeige, Projektbau und Verlinkung prüft nur ein einmaliger Simulatorlauf, automatisch nichts.

## Kritische Anmerkungen

- Laboranzeige, Projektbau und Verlinkung (AC-7 bis 9) haben keinen automatischen Test; spätere Rückfälle bleiben unbemerkt.
- Export aus Hennings Store, Gewichtung nach seiner Verteilung und Laborlauf fehlen; Issue #88 bleibt offen.
- Projektdatei steht auf der Geräteliste; Gerätetest erst nach Hennings Wort "jetzt ist ein Test möglich".

## Freigabe-Frage

Gibst du diesen Teilschritt ohne Export und Gewichtung frei?
