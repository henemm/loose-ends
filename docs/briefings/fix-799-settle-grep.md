---
spec_file: docs/specs/tooling/fix-799-settle-grep.md
spec_sha256: 1ea10956b2ef7200278e695734a1e355f6b99d1c453ae90cf06323f0e82feb00
spec_frozen_sha256: dce8a0fd34b3ec6993859eaa4e29ee5b7215c7f0324b6934e354a2e79c21bf8c
---

# PO-Briefing: fix-799-settle-grep

- **Spec:** docs/specs/tooling/fix-799-settle-grep.md
- **Issue:** #799
- **Erstellt:** 2026-11-02

## Was gebaut wird

Der automatische Testlauf bricht nicht mehr ab, wenn der Simulator beim Warten schon ruhig ist.

## Definition of Done

Der Testlauf auf dem PR geht in allen Sprachen am Warteschritt vorbei, und die Prüfskripte sind grün.

## Wie geprüft wird

Ein neuer Skripttest belegt das Verhalten ohne Poster-Prozess lokal; der echte Nachweis folgt erst im Testlauf auf dem PR.

## Kritische Anmerkungen

- Der Lauf auf dem PR ist nur noch Definition of Done, kein Acceptance Criterion; das Ziel bleibt, wird aber nicht vorab vom Gate erzwungen.
- Der Fehler hängt vom Zeitpunkt ab; ein einzelner grüner Lauf beweist wenig, der lokale Nachstellversuch trägt den Beweis.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
