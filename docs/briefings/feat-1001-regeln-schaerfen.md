---
spec_file: docs/specs/enrichment/feat-1001-tageszeit-im-titel.md
spec_sha256: 28a8e6d6e85a67a40781c25422c71d19cf1c29e037bff11260d81fa7f96bd945
spec_frozen_sha256: ea7b110010521351544545587b466bc23ab8fb7be8a90fc5b6e5cbff382cf9b8
---

# PO-Briefing: feat-1001-regeln-schaerfen

- **Spec:** docs/specs/enrichment/feat-1001-tageszeit-im-titel.md
- **Issue:** #1001
- **Erstellt:** 2026-11-27

## Was gebaut wird

Tageszeitwörter wie „heute Morgen“ oder „morgen früh“ verschwinden aus dem Aufgabentitel, ohne dass Uhrzeiten erfunden werden.

## Definition of Done

Im Simulator ergibt „Pakete wegbringen heute Morgen“ den Titel „Pakete wegbringen“, und alle automatischen Tests sind grün.

## Wie geprüft wird

Tests belegen Beispiele und Gegenproben („Abendessen“ bleibt); sie beweisen nicht, dass andere Titelfehler verschwinden.

## Kritische Anmerkungen

- Nur eine Fehlerklasse: Titel stimmen laut Messung nur bei 16 statt 14 von 41 Korrekturen; Rest nicht per Regel lösbar.
- Zusatz: „tonight“ setzt künftig das Datum heute; im Issue nicht verlangt.
- Feldregeln (Dauer, Kontext) bleiben unverändert, obwohl das Issue auch „Felder“ nennt.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
