---
spec_file: docs/specs/measurement/spike-65-mehrfachlauf-infrastruktur.md
spec_sha256: 17b01c2a497565240ec968ccd13dd466c52b5e6d413db52d8844490ae115ac61
---

# PO-Briefing: spike-65-unsicherheitssignal

- **Spec:** docs/specs/measurement/spike-65-mehrfachlauf-infrastruktur.md
- **Issue:** keine (Analyse-Kontext: docs/context/spike-65-unsicherheitssignal.md, Issue #65)
- **Erstellt:** 2026-09-22

## Was gebaut wird

Die Mess-Werkzeuge lernen, mehrere Testdurchläufe pro Satz zu zählen und ein zweites Test-Set zu laden.

## Definition of Done

Alle sechs Prüfpunkte sind durch automatisierte Tests belegt, bestehende Tests bleiben unverändert grün.

## Wie geprüft wird

Automatisierte Tests am Mac zeigen korrektes Zählen und Laden; bei drei von sechs Punkten indirekt über ausgelagerte Bausteine, nicht direkt an der App.

## Kritische Anmerkungen

- Bei drei von sechs Prüfpunkten testen die Tests nur ausgelagerte Bausteine, nicht die tatsächliche App direkt.
- Beantwortet die Ausgangsfrage aus #65 noch nicht: kein Signal gemessen, kein Report, keine Empfehlung — nur Vorbereitung.
- Sub-Issues für diesen und den nächsten Schritt fehlen noch, werden erst nach Freigabe angelegt.

## Freigabe-Frage

Ist es in Ordnung, dass diese reine Vorbereitung freigegeben wird, obwohl ein Teil der Prüfung nur indirekt über Hilfsbausteine läuft?
