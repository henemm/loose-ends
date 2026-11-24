---
spec_file: docs/specs/fix-978-s3-wiederoeffnen-warten.md
spec_sha256: 2f85fb89794bead0d78c1c543c667319cd17665b14f5ae968e2169d89c64fb57
spec_frozen_sha256: dbf73494215088e0e20f5bfc0fbbd09aa4747be6a4851949505c53a10c3b5f0a
---

# PO-Briefing: fix-978-s3-wiederoeffnen-warten

- **Spec:** docs/specs/fix-978-s3-wiederoeffnen-warten.md
- **Issue:** #978
- **Erstellt:** 2026-11-24

## Was gebaut wird

Der automatische Pflicht-Test für das Wiedereröffnen des Menüleisten-Panels klickt anders und prüft wieder streng, statt Fehler zu ignorieren.

## Definition of Done

Der Pflicht-Test läuft dreimal hintereinander grün ohne Ausnahmeregel, und in über 100 Wiederholungen je Testvariante schließt sich das Panel kein einziges Mal.

## Wie geprüft wird

Skripttests prüfen den Testcode, Probe, Wiederholungsläufe und Pflichtläufe in der CI belegen die Wirkung; Nutzer-Betroffenheit wird nicht geprüft.

## Kritische Anmerkungen

- Ob der neue Klickweg das Problem wirklich behebt, ist unbelegt; erst der Probelauf entscheidet, sonst Rückfallplan.
- Fehlerrate ist winzig (etwa 0,5 %); 100 fehlerfreie Läufe sind nur eine Stichprobe, kein Beweis.
- App selbst bleibt unverändert; ob echte Nutzer das Zuklappen erleben, ist nicht belegt.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
