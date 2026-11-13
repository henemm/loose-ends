---
spec_file: docs/specs/feat-795-schnitt-3b1-ausloeser.md
spec_sha256: 043c4e2428367857a1646628b67cb2dfa36e5eebbfe23f875698c3d44bfc9334
spec_frozen_sha256: fec97f915c6f43c3e8fdc6fe80e95e1b9da7ed5a8b09d1abd913bade8e318c20
---

# PO-Briefing: feat-795-s3b-ausloeser

- **Spec:** docs/specs/feat-795-schnitt-3b1-ausloeser.md
- **Issue:** #795
- **Erstellt:** 2026-11-12

## Was gebaut wird

Die App meldet sich bei verbundenem Claude-Konto von selbst beim Dienst und holt Aufträge von Claude ab.

## Definition of Done

Alle Tests grün, die App startet im Simulator unverändert ohne Absturz, und ohne Konto geht keine einzige Anfrage ins Netz.

## Wie geprüft wird

Tests zählen Auslöser, Reihenfolge, Verzögerung und Konto-Regel mit Attrappen; ob die Kette bis zum echten Dienst schliesst, zeigt erst der Folgeschnitt.

## Kritische Anmerkungen

- Kein Nachweis gegen den echten Dienst in diesem Schnitt; das folgt bewusst im nächsten Teilschnitt.
- Mac nur mit Menüleisten-Symbol: Aufträge können bis zum späteren Weckruf warten; nicht belegt, als Grenze benannt.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
