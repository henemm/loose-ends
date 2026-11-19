---
spec_file: docs/specs/bug-953-claude-titel.md
spec_sha256: f6561bcd921dfbe654174161af47e535dd67455082d62a5ed2492553e719da6d
spec_frozen_sha256: c9f8b0e737b031d5e4a98718812d83e009276e48c3f198c2c51d65964059e45c
---

# PO-Briefing: fix-953-claude-titel

- **Spec:** docs/specs/bug-953-claude-titel.md
- **Issue:** #953
- **Erstellt:** 2026-11-19

## Was gebaut wird

Aufgaben, die Claude anlegt, behalten in der App ihre Überschrift; das Modell schreibt sie nicht mehr um.

## Definition of Done

Die Gartenhütten-Aufgabe aus Claude behält ihre volle Überschrift, beim ersten Analysieren und bei „Erneut analysieren“; Dauer und übrige Felder werden weiter gesetzt.

## Wie geprüft wird

Sechs automatische Tests und ein Simulatorlauf mit Ersatzmodell weisen es nach; das echte Apple-Modell und ältere Geräte werden nicht geprüft.

## Kritische Anmerkungen

- Die feste Regel kürzt Claudes Text weiter auf höchstens 12 Wörter und streicht Datumswörter; nur das Modell wird ausgesperrt.
- Bereits umgeschriebene Überschriften bleiben, wie sie sind; ältere Geräte können neue Claude-Aufgaben vorerst weiter umschreiben.
- Die Frage zu „update_task“ ist nur in der Analyse beantwortet, ein eigener Test dafür fehlt.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
