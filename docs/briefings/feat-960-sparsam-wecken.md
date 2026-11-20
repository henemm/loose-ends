---
spec_file: docs/specs/feat-960-sparsam-wecken.md
spec_sha256: 60dbc501c3f14d8e125b00c52f0eed4be40c96e9964b243699a8ad32fa1ec387
spec_frozen_sha256: 286f005d7bba0ae3a2f448dc4732087de94a068ef6ac32569b3b7382e60f7a1e
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

Automatische Dienst-Tests beweisen Drosselung, Nachholen und Gerätetrennung; ob iOS auf dem Akku-iPhone dann zuverlässig abholt, beweist nur der spätere Betriebsbeleg.

## Kritische Anmerkungen

- Nach dem ersten Weckruf folgt ein zweiter am Viertelstundenende; im Dauerfeuer vier je Stunde, über Apples Richtwert von zwei bis drei.
- Ob das Akku-Problem damit gelöst ist, ist offen; Wirkung auf dem Gerät wird nicht getestet.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
