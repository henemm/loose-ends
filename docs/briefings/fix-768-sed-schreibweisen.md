---
spec_file: docs/specs/fast/fix-768-sed-schreibweisen.md
spec_sha256: 7e969f75c3f0b728f0cc15cde5cc4512be387c8749fac9dae4fd49a10ca1107c
spec_frozen_sha256: 0f618a7352c3f7d5b817b26899f58eb2ddc31e55843276676e8a3bc652223d14
---

# PO-Briefing: fix-768-sed-schreibweisen

- **Spec:** docs/specs/fast/fix-768-sed-schreibweisen.md
- **Issue:** #768
- **Erstellt:** 2026-11-02

## Was gebaut wird

Der Schutztest gegen heimliches Absenken der Xcode-Version erkennt Dateien-ändernde Befehle künftig in jeder Schreibweise.

## Definition of Done

Der Schutztest schlägt bei jeder der vier schreibenden Schreibweisen an, lesende Zeilen bleiben erlaubt, und die gesamte Skript-Testsuite läuft grün durch.

## Wie geprüft wird

Eine Gegenprobe in einer Kopie fügt je Schreibweise eine Zeile ein und erwartet Alarm; nicht geprüft wird, ob jede denkbare Variante erkannt wird.

## Kritische Anmerkungen

- Die zehn vorhandenen lesenden Zeilen in den Arbeitsabläufen löst das Muster nicht aus (von mir geprüft); die Spec belegt das nur mit einer Beispielzeile.
- Schreibendes Flag hinter dem Skript (`sed 's/a/b/' -i datei`) bleibt unerkannt; Ticket verlangt es nicht.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
