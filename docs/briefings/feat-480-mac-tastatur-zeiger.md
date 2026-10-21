---
spec_file: docs/specs/feat-480-schnitt-1-liste.md
spec_sha256: 8b049a757eb4b45e7a4dfa8ca4e353a7e8143a9b43416eff2551be12544fb210
spec_frozen_sha256: 21859a4f3d2caba4d67767a6c309e4206fd767c54d1f35dd00658122a4fbc748
---

# PO-Briefing: feat-480-mac-tastatur-zeiger

- **Spec:** docs/specs/feat-480-schnitt-1-liste.md
- **Issue:** #480
- **Erstellt:** 2026-10-20

## Was gebaut wird

In Mac-Listen wählst du Aufgaben mit Pfeiltasten, erledigst mit Leertaste und löschst mit Rücktaste nach Rückfrage.

## Definition of Done

Pfeile, Leertaste und Rücktaste wirken in jeder Liste, nicht im Suchfeld; die gewählte Zeile ist akzentfarben; iPhone bleibt unverändert.

## Wie geprüft wird

Unit-Test der Tastenzuordnung und Mac-Oberflächentests samt Fotos in der CI; nicht geprüft wird auf deinem echten Mac.

## Kritische Anmerkungen

- Startseite und Mindestgröße 760 × 520 fehlen in diesem Schnitt (Abweichung vom Ticket); Ticket bleibt offen.
- Ob Leertaste und Rücktaste in der Liste zuverlässig ankommen, ist ungeklärt; Rückfall könnte Verhalten ändern.
- Abnahme auf dem Mac erst nach Schnitt 2; bis dahin nur CI-Läufe und Fotos.

## Freigabe-Frage

Gibst du die Aufteilung frei, sodass zuerst nur die Listen kommen und Startseite samt Mindestgröße folgen?
