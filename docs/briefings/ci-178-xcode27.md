---
spec_file: docs/specs/tooling/fix-178-ci-xcode27.md
spec_sha256: ea01027fb78db817d161b8d21d7ab2072567f2ab754e51b750d667301e49e9e6
---

# PO-Briefing: ci-178-xcode27

- **Spec:** docs/specs/tooling/fix-178-ci-xcode27.md
- **Issue:** #178
- **Erstellt:** 2026-10-06

## Was gebaut wird

Die automatische Prüfung läuft mit exakt derselben Xcode-Version und demselben Zielsystem wie bei dir, und der Sprachtest wird stabil.

## Definition of Done

Alle drei Prüfläufe sind mit Xcode 27.0 grün, der Sprach-Belastungstest läuft zehnmal grün, jeweils unter fünf Minuten, ohne Absenkung auf 26.

## Wie geprüft wird

Echte Prüfläufe auf GitHub belegen es; für den Dialog-Wettlauf gibt es keinen lokalen Test, nur den Zehnfach-Lauf.

## Kritische Anmerkungen

- Ein Testskript fehlt in der Dateiliste: tatsächlich sieben Dateien, nicht sechs.
- Wird die Oberfläche-Prüfung wegen des Sprachmodells rot, gibt es keine Wiederholung; das Ticket hängt dann an #208.
- Zeitvergleich ohne Schwelle: „mit Bewertung" lässt offen, wann die längere oder kürzere Laufzeit akzeptabel ist.

## Freigabe-Frage

Gibst du die Umstellung auf die Vorschau-Prüfumgebung samt Sprachtest-Korrektur frei, obwohl Rot durch das Sprachmodell möglich bleibt?
