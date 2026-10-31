---
spec_file: docs/specs/fix-780-bgrefresh-queue.md
spec_sha256: 81fde14715524896d5fc5386dc4f731c037c11087a50fee7d5b6bfb562cb83d4
spec_frozen_sha256: e1c8edd1bd9df8339c1f731c0dcf5d14dcf2b6d8ed5931ddd10ce393541747fc
---

# PO-Briefing: fix-780-bgrefresh-queue

- **Spec:** docs/specs/fix-780-bgrefresh-queue.md
- **Issue:** #780
- **Erstellt:** 2026-10-31

## Was gebaut wird

Die tägliche Hintergrund-Auffrischung der Mitteilungen stürzt nicht mehr ab, wenn iOS sie startet.

## Definition of Done

Nach einigen Tagen TestFlight-Nutzung zeigt der Absturz-Abruf für neue Builds keine Meldung der Hintergrund-Auffrischung mehr.

## Wie geprüft wird

Tests und ein Nachbau belegen Verhalten und Absturzursache; ob iOS sie auf dem echten Gerät stabil startet, zeigt erst der spätere Abruf.

## Kritische Anmerkungen

- Die Tests wären beim heutigen Code nicht rot geworden; den Absturz belegt nur ein Nachbau, nicht das echte iOS.
- Zwei weitere Rückrufe werden vorsorglich mitgesichert, obwohl dafür noch kein Absturz gemeldet wurde.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
