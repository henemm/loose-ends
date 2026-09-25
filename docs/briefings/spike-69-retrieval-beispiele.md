---
spec_file: docs/specs/measurement/spike-69-regel-baseline-konventionstest.md
spec_sha256: 70a88b052f31e328e96a15a0aec588947de8009d8211d3cbbc153dfbac309caf
---

# PO-Briefing: spike-69-retrieval-beispiele

- **Spec:** docs/specs/measurement/spike-69-regel-baseline-konventionstest.md
- **Issue:** #69
- **Erstellt:** 2026-09-25

## Was gebaut wird

Ein Testlauf prüft, ob einfache Regeln aus drei früheren Korrekturen automatisch den richtigen Aufgaben-Kontext erraten.

## Definition of Done

Ein Bericht zeigt die Trefferquote von zehn Testfällen; ab acht Treffern gilt die Regel als bewährt.

## Wie geprüft wird

Automatisierte Tests prüfen jede Regel einzeln und den Gesamtbericht; echte Sprachmodell- oder Gerätetests finden nicht statt.

## Kritische Anmerkungen

- Deckt nur einen Teil der Anfrage: der Vergleich mit KI-Vorschlägen (Embeddings) fehlt noch komplett.
- Ob die bisherige Lernmethode (ähnliche alte Aufgaben zeigen) ersetzt wird, entscheidet sich erst nach diesem und einem möglichen Folgetest.
- Geprüft wird nur Wort-zu-Kontext, nicht Wort-zu-Projekt — dafür fehlen echte Beispieldaten.

## Freigabe-Frage

Reicht dir dieser erste Teilschritt jetzt, obwohl die volle Ursprungsanfrage noch offen bleibt?
