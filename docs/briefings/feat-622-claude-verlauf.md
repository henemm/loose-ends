---
spec_file: docs/specs/feat-622-schnitt-1-claude-revisionen.md
spec_sha256: 1f01602fe984c9191ba553b66149bd5c866a00f1e87b81d7c06329ab869e83f9
spec_frozen_sha256: 56de9cbcce5afb2b1637d92797e58723cf1d07b9973deb990cc6570618b0d110
---

# PO-Briefing: feat-622-claude-verlauf

- **Spec:** docs/specs/feat-622-schnitt-1-claude-revisionen.md
- **Issue:** #622
- **Erstellt:** 2026-11-15

## Was gebaut wird

Aufträge von Claude (erledigen, parken, als Nächstes, Teilaufgabe) hinterlassen eine Spur mit Grund „Claude“ im Änderungsverlauf der Aufgabe.

## Definition of Done

Jeder dieser vier Aufträge schreibt genau eine Verlaufszeile mit Grund Claude; abgelehnte Aufträge schreiben keine; alle Tests und der Simulator-Durchlauf sind grün.

## Wie geprüft wird

Neun automatisierte Tests prüfen die Verlaufszeilen je Auftragsart; sichtbar in der App ist noch nichts, und der Nachweis aus claude.ai fehlt.

## Kritische Anmerkungen

- Sichtbarkeit in der App und claude.ai-Nachweis fehlen hier bewusst; das Ticket bleibt offen, bis Schnitt 2 folgt.
- Kein Test prüft, dass ein schon vorhandener Grund nicht überschrieben wird (Teil von AC-7).

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
