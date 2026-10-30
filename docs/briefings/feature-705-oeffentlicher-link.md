---
spec_file: docs/specs/feat-705-schnitt-2b2c-oeffentlicher-link.md
spec_sha256: bab0569fe07b24a13c1338841ff0f5ec939306961853035ee08fc11cf44f7d64
spec_frozen_sha256: dd73fd5c49c595a53801a49e918466fe6a11a59a3ff9e738f51537a2e6894cf9
---

# PO-Briefing: feature-705-oeffentlicher-link

- **Spec:** docs/specs/feat-705-schnitt-2b2c-oeffentlicher-link.md
- **Issue:** #705
- **Erstellt:** 2026-10-30

## Was gebaut wird

Ein Handlauf schaltet den öffentlichen Einladungslink der Testgruppe mit höchstens 50 Plätzen ein oder wieder aus.

## Definition of Done

Nach deinem ausdrücklichen Wort zeigt die Prüfung den Link als eingeschaltet, ein zweiter Lauf ändert nichts, und du findest den Link in App Store Connect.

## Wie geprüft wird

Automatische Tests gegen einen Nachbau von Apples Schnittstelle belegen Schutzregeln und Ausgabe; ob Apple das Limit wirklich annimmt, zeigt erst der echte Lauf.

## Kritische Anmerkungen

- Unbelegt, ob Apple das Limit 50 per Schlüssel annimmt; sonst schaltet das Skript zurück und du aktivierst den Link von Hand.
- Der echte Lauf ist kein Testfall: erst nach #743 (Link im öffentlichen Protokoll maskieren) und deinem Wort.
- Neue Builds sind nicht automatisch im Link; das regelt erst #724.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
