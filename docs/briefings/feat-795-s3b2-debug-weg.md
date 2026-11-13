---
spec_file: docs/specs/feat-795-schnitt-3b2-debug-weg.md
spec_sha256: 0e2ef933d9cdb9c39fbf7c893baf60b5bc570b23cd4abbdc7bcca8173d6ddbfc
spec_frozen_sha256: 796385f6656527d4f08b0229c204757078da05f29e46fdfb26c1593760a3b0b1
---

# PO-Briefing: feat-795-s3b2-debug-weg

- **Spec:** docs/specs/feat-795-schnitt-3b2-debug-weg.md
- **Issue:** #795
- **Erstellt:** 2026-11-13

## Was gebaut wird

Entwickler können die Verbindung zwischen App und Claude-Dienst lokal im Simulator komplett durchspielen; für Nutzer ändert sich nichts.

## Definition of Done

Zwei Simulatoren laufen gegen einen lokalen Dienst: Abschrift von A im Dienst, Auftrag auf B als Revision „Claude“ ausgeführt, Ergebnis im Dienst.

## Wie geprüft wird

Acht automatische Tests sichern die Schutzregeln, ein echter Durchlauf belegt die Kette; Apple-Anmeldung und Internet-Server bleiben ungeprüft.

## Kritische Anmerkungen

- Zusatz: signierter Simulatorbau nur auf Schalter; Standard und CI bleiben unverändert.
- Skript- und Simulator-Belege sind Protokolle, keine automatischen Tests.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
