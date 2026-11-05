---
spec_file: docs/specs/feat-621-schnitt-2-ablage.md
spec_sha256: 7d315a5f7416acf7cf89b7cb32e90683d7384ddb6f73cf1bf564284c3a7bce35
spec_frozen_sha256: 49c7a6850cb7fb2ea88d0d838688f3317cc36e7efaa5ed25b2e3c98c77a744c3
---

# PO-Briefing: feat-621-s2-ablage

- **Spec:** docs/specs/feat-621-schnitt-2-ablage.md
- **Issue:** #621
- **Erstellt:** 2026-11-05

## Was gebaut wird

Der Dienst bekommt ein verborgenes Gedächtnis für Claude-Anmeldungen, damit sich Claude später verbinden kann; sichtbar ändert sich nichts.

## Definition of Done

Alle 18 Kriterien erfüllt, Servertests und automatische Prüfung grün; Tür für Claude bleibt zu, Kontolöschung entfernt auch diese Einträge.

## Wie geprüft wird

Automatische Tests gegen eine Wegwerf-Datenbank belegen Einmal-Einlösen, Ablauf und Löschung; echtes Zusammenspiel mit der Anmeldebibliothek zeigt erst der Folgeschnitt.

## Kritische Anmerkungen

- Umfang etwa 500 statt 250 Zeilen (meist Sicherheitstests); die Spec verlangt, dass die Freigabe das ausdrücklich annimmt.
- Der in der Planung vorgesehene Sitzungsablauf entfällt hier und wandert zur App-Anmeldung (#615); Folge: App-Sitzungen laufen vorerst nie ab.
- Dateiliste (genau sechs Dateien) wird nur bei der Abschlussprüfung belegt, nicht durch einen Test.

## Freigabe-Frage

Nimmst du den dreifachen Umfang (etwa 500 Zeilen) und die Verschiebung des Sitzungsablaufs zur App-Anmeldung so an?

## Ampel

Ampel: rot
