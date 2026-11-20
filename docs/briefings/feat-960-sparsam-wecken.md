---
spec_file: docs/specs/feat-960-sparsam-wecken.md
spec_sha256: 4d90ad36ea014af2aa9eeb27c72040bbacd36a05a5b9e8d06484a7e0ac895332
spec_frozen_sha256: 754de9ff02ee6de0dc61a26c04c14a4b275bc8c56ba0e950c8f71b4732923550
---

# PO-Briefing: feat-960-sparsam-wecken

- **Spec:** docs/specs/feat-960-sparsam-wecken.md
- **Issue:** #960
- **Erstellt:** 2026-11-20

## Was gebaut wird

Der Dienst weckt jedes Gerät höchstens einmal je Viertelstunde, damit iOS die Weckrufe nicht ausbremst.

## Definition of Done

Im Dienstprotokoll erscheint bei einer Auftragsserie je Gerät höchstens ein Weckruf binnen 15 Minuten, und kein Auftrag bleibt liegen.

## Wie geprüft wird

Automatische Dienst-Tests beweisen Drosselung, Nachholen und Gerätetrennung; ob das Akku-iPhone dann zuverlässig abholt, zeigt nur der spätere Betriebsbeleg.

## Kritische Anmerkungen

- Im Dauerfeuer entstehen vier Weckrufe je Stunde, über Apples Richtwert von zwei bis drei; Akku-Problem eventuell nicht gelöst.
- Wirkung auf dem Gerät wird nicht getestet, nur der Dienstlog.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
