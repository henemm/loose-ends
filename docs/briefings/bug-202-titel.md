---
spec_file: docs/specs/fix-202-titel-regel.md
spec_sha256: f8c34175a881d81e51bc354b1a15343771a82af06919412792f78d47a373208f
---

# PO-Briefing: bug-202-titel

- **Spec:** docs/specs/fix-202-titel-regel.md
- **Issue:** #202
- **Erstellt:** 2026-10-05

## Was gebaut wird

Jede erfasste Aufgabe bekommt sofort einen Titel aus dem Gesagten; Zurücksetzen führt darauf, nie auf ein leeres Feld.

## Definition of Done

Neue Aufgaben zeigen auch ohne Apple Intelligence einen Titel; Zurücksetzen nach KI-Titel liefert den Anfangstitel statt eines leeren Feldes.

## Wie geprüft wird

Tests im Simulator belegen Regel, Erfassung und Zurücksetzen; Modell auf dem iPhone, Mitteilungen, Kalender und Widget bleiben ungetestet.

## Kritische Anmerkungen

- Neun statt 4–5 Dateien; nur vier davon Produktivcode, Rest Tests und Doku.
- Liste, Mitteilungen, Kalender, Widget zeigen künftig gekürzten Titel statt Rohtext (nicht verlangt); AC-7 und AC-9 ohne Test.
- Modelltitel auf dem iPhone bleibt unzuverlässig (#159); „iPhone laden“ wird „IPhone laden“.

## Freigabe-Frage

Geben Sie die Aufgabe mit neun Dateien und dem geänderten Listentitel frei?
